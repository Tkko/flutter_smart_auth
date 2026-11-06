package dev.tornike.smart_auth

import android.app.Activity
import android.app.Activity.RESULT_CANCELED
import android.app.Activity.RESULT_OK
import android.content.*
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.app.ActivityCompat.startIntentSenderForResult
import androidx.core.content.ContextCompat
import com.google.android.gms.auth.api.identity.GetPhoneNumberHintIntentRequest
import com.google.android.gms.auth.api.identity.Identity
import com.google.android.gms.auth.api.phone.SmsRetriever
import com.google.android.gms.common.api.CommonStatusCodes
import com.google.android.gms.common.api.Status
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.PluginRegistry
import kotlinx.coroutines.suspendCancellableCoroutine


/** SmartAuthPlugin */
class SmartAuthPlugin : FlutterPlugin, ActivityAware, PluginRegistry.ActivityResultListener,
    SmartAuthApi {
    private lateinit var mContext: Context
    private lateinit var credentialManager: CredentialManagerHelper
    private val mainHandler = Handler(Looper.getMainLooper())
    private var mActivity: Activity? = null
    private var mBinding: ActivityPluginBinding? = null
    private var pendingSmsResult: ((Result<String>) -> Unit)? = null
    private var pendingHintResult: ((Result<String>) -> Unit)? = null
    private var smsReceiver: SmsBroadcastReceiver? = null
    private var consentReceiver: ConsentBroadcastReceiver? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        mContext = flutterPluginBinding.applicationContext
        credentialManager = CredentialManagerHelper(mContext)
        SmartAuthApi.setUp(flutterPluginBinding.binaryMessenger, this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        SmartAuthApi.setUp(binding.binaryMessenger, null)
        dispose()
    }

    override fun onDetachedFromActivity() {
        detachActivity()
    }

    override fun onDetachedFromActivityForConfigChanges() {
        detachActivity()
    }


    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        mActivity = binding.activity
        mBinding = binding
        binding.addActivityResultListener(this)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        mActivity = binding.activity
        mBinding = binding
        binding.addActivityResultListener(this)
    }


    override fun onActivityResult(
        requestCode: Int, resultCode: Int, data: Intent?
    ): Boolean {
        when (requestCode) {
            PHONE_NUMBER_HINT_REQUEST -> onPhoneNumberHintRequest(resultCode, data)
            USER_CONSENT_REQUEST -> onSmsConsentRequest(resultCode, data)
        }
        return true
    }

    override fun getAppSignature(): String {
        val signatures = AppSignatureHelper(mContext).getAppSignatures()
        return signatures.getOrNull(0) ?: ""
    }


    override suspend fun getSmsWithRetrieverApi(): String = suspendCancellableCoroutine { cont ->
        cancelPendingSmsRequest()
        pendingSmsResult = { cont.resumeWith(it) }
        cont.invokeOnCancellation {
            consumeSmsResult()
            unregisterSmsReceiver()
        }
        smsReceiver = SmsBroadcastReceiver()
        val intentFilter = IntentFilter(SmsRetriever.SMS_RETRIEVED_ACTION)
        ContextCompat.registerReceiver(
            mContext,
            smsReceiver,
            intentFilter,
            SmsRetriever.SEND_PERMISSION,
            null,
            ContextCompat.RECEIVER_EXPORTED
        )
        SmsRetriever.getClient(mContext).startSmsRetriever()
    }

    override suspend fun getSmsWithUserConsentApi(phoneNumber: String?): String =
        suspendCancellableCoroutine { cont ->
        cancelPendingSmsRequest()
        pendingSmsResult = { cont.resumeWith(it) }
        cont.invokeOnCancellation {
            consumeSmsResult()
            unregisterConsentReceiver()
        }
        consentReceiver = ConsentBroadcastReceiver()
        val intentFilter = IntentFilter(SmsRetriever.SMS_RETRIEVED_ACTION)
        ContextCompat.registerReceiver(
            mContext,
            consentReceiver,
            intentFilter,
            SmsRetriever.SEND_PERMISSION,
            null,
            ContextCompat.RECEIVER_EXPORTED
        )
        SmsRetriever.getClient(mContext).startSmsUserConsent(phoneNumber)
    }


    // The SMS calls are suspend functions, which start on a later main thread
    // tick. Queue the removal behind them, otherwise a call made right before
    // it would start after the removal and never finish.
    override fun removeSmsRetrieverListener() {
        mainHandler.post {
            if (smsReceiver != null) {
                cancelPendingSmsRequest()
            }
        }
    }

    override fun removeUserConsentListener() {
        mainHandler.post {
            if (consentReceiver != null) {
                cancelPendingSmsRequest()
            }
        }
    }


    override suspend fun requestPhoneNumberHint(): String = suspendCancellableCoroutine { cont ->
        val activity = mActivity
        if (activity == null) {
            cont.resumeWith(
                Result.failure(
                    FlutterError(
                        "NO_ACTIVITY",
                        "Phone number hint requires a foreground activity.",
                        null
                    )
                )
            )
            return@suspendCancellableCoroutine
        }
        ignoreIllegalState { consumeHintResult()?.invoke(Result.failure(hintCanceledError())) }
        pendingHintResult = { cont.resumeWith(it) }
        cont.invokeOnCancellation {
            consumeHintResult()
        }
        val hintRequest = GetPhoneNumberHintIntentRequest.builder().build()

        val signInClient = Identity.getSignInClient(mContext)
        signInClient.getPhoneNumberHintIntent(hintRequest).addOnSuccessListener { pendingIntent ->
            val currentActivity = mActivity
            if (currentActivity != null) {
                try {
                    startIntentSenderForResult(
                        currentActivity,
                        pendingIntent.intentSender,
                        PHONE_NUMBER_HINT_REQUEST,
                        null,
                        0,
                        0,
                        0,
                        null
                    )
                } catch (e: Exception) {
                    val message = "Failed to start phone number hint intent: ${e.message}"
                    Log.e(PLUGIN_TAG, message)
                    consumeHintResult()?.invoke(Result.failure(Exception(message)))
                }
            } else {
                val message = "Activity was detached before launching phone number hint intent."
                Log.e(PLUGIN_TAG, message)
                consumeHintResult()?.invoke(
                    Result.failure(
                        FlutterError(
                            "NO_ACTIVITY",
                            message,
                            null
                        )
                    )
                )
            }
        }.addOnFailureListener { exception ->
            val message = "Failed to get phone number hint intent: ${exception.message}"
            Log.e(PLUGIN_TAG, message)
            consumeHintResult()?.invoke(Result.failure(Exception(message)))
        }
    }

    override suspend fun getCredential(
        request: SmartAuthGetCredentialRequest
    ): SmartAuthCredential = credentialManager.getCredential(mActivity, request)

    override suspend fun createCredential(
        request: SmartAuthCreateCredentialRequest
    ): SmartAuthCreateCredentialResponse = credentialManager.createCredential(mActivity, request)

    override suspend fun prepareGetCredential(
        request: SmartAuthGetCredentialRequest
    ): SmartAuthPreparedCredential = credentialManager.prepareGetCredential(request)

    override suspend fun getPreparedCredential(): SmartAuthCredential =
        credentialManager.getPreparedCredential(mActivity)

    override suspend fun clearCredentialState() = credentialManager.clearCredentialState()

    private fun consumeSmsResult(): ((Result<String>) -> Unit)? {
        val result = pendingSmsResult
        pendingSmsResult = null
        return result
    }

    private fun consumeHintResult(): ((Result<String>) -> Unit)? {
        val result = pendingHintResult
        pendingHintResult = null
        return result
    }

    /** Stops listening and finishes a waiting SMS call, so its Future doesn't hang. */
    private fun cancelPendingSmsRequest() {
        unregisterAllReceivers()
        ignoreIllegalState {
            consumeSmsResult()?.invoke(
                Result.failure(
                    FlutterError(
                        "SMS_REQUEST_CANCELED",
                        "SMS request was canceled.",
                        SmartAuthRequestCanceled()
                    )
                )
            )
        }
    }

    private fun hintCanceledError() = FlutterError(
        "PHONE_NUMBER_HINT_CANCELED",
        "User canceled phone number hint request.",
        SmartAuthRequestCanceled()
    )

    /// Callbacks
    private fun onSmsConsentRequest(resultCode: Int, data: Intent?) {
        if (resultCode == RESULT_OK && data != null) {
            val message = data.getStringExtra(SmsRetriever.EXTRA_SMS_MESSAGE)
            if (message == null) {
                ignoreIllegalState {
                    consumeSmsResult()?.invoke(
                        Result.failure(
                            Exception("Failed to get SMS with user consent.")
                        )
                    )
                }
                return
            }
            ignoreIllegalState { consumeSmsResult()?.invoke(Result.success(message)) }
            return
        }

        if (resultCode == RESULT_CANCELED) {
            ignoreIllegalState {
                consumeSmsResult()?.invoke(
                    Result.failure(
                        FlutterError(
                            "USER_CONSENT_CANCELED",
                            "User canceled SMS consent request.",
                            SmartAuthRequestCanceled()
                        )
                    )
                )
            }
            return
        }

        ignoreIllegalState {
            consumeSmsResult()?.invoke(
                Result.failure(
                    Exception("Failed to get SMS with user consent.")
                )
            )
        }

    }

    private fun onPhoneNumberHintRequest(resultCode: Int, data: Intent?) {
        if (resultCode == RESULT_OK && data != null) {
            try {
                val phoneNumber = Identity.getSignInClient(mContext).getPhoneNumberFromIntent(data)
                ignoreIllegalState {
                    consumeHintResult()?.invoke(Result.success(phoneNumber))
                }
            } catch (e: Exception) {
                val message = "Failed to get phone number from intent: ${e.message}"
                Log.e(PLUGIN_TAG, message)
                ignoreIllegalState {
                    consumeHintResult()?.invoke(Result.failure(Exception(message)))
                }
            }
            return
        }

        if (resultCode == RESULT_CANCELED) {
            ignoreIllegalState {
                consumeHintResult()?.invoke(
                    Result.failure(
                        hintCanceledError()
                    )
                )
            }
            return
        }

        val message = "Failed to get phone number hint with resultCode: $resultCode"
        Log.e(PLUGIN_TAG, message)
        ignoreIllegalState {
            consumeHintResult()?.invoke(
                Result.failure(
                    FlutterError(
                        "PHONE_NUMBER_HINT_FAILED", message, null
                    )
                )
            )
        }
    }


    private fun detachActivity() {
        mActivity = null
        mBinding?.removeActivityResultListener(this)
        mBinding = null
    }

    private fun dispose() {
        unregisterAllReceivers()
        credentialManager.dispose()
        consumeSmsResult()
        consumeHintResult()
        detachActivity()
    }

    private fun unregisterAllReceivers() {
        unregisterSmsReceiver()
        unregisterConsentReceiver()
    }

    private fun unregisterSmsReceiver() {
        if (smsReceiver != null) {
            unregisterReceiver(smsReceiver)
            smsReceiver = null
        }
    }

    private fun unregisterConsentReceiver() {
        if (consentReceiver != null) {
            unregisterReceiver(consentReceiver)
            consentReceiver = null
        }
    }


    private fun unregisterReceiver(receiver: BroadcastReceiver?) {
        try {
            receiver?.let { mContext.unregisterReceiver(it) }
        } catch (exception: Exception) {
            Log.e(PLUGIN_TAG, "Unregistering receiver failed.", exception)
        }
    }

    private fun ignoreIllegalState(fn: () -> Unit) {
        try {
            fn()
        } catch (e: IllegalStateException) {
            Log.e(PLUGIN_TAG, "ignoring exception: $e")
        }
    }

    /**
     * SMS Retriever API
     * [https://developers.google.com/identity/sms-retriever/overview]
     */
    inner class SmsBroadcastReceiver : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (SmsRetriever.SMS_RETRIEVED_ACTION == intent.action) {
                unregisterSmsReceiver()
                if (intent.extras != null && intent.extras!!.containsKey(SmsRetriever.EXTRA_STATUS)) {
                    val extras = intent.extras!!
                    val smsRetrieverStatus = extras.get(SmsRetriever.EXTRA_STATUS) as Status
                    when (smsRetrieverStatus.statusCode) {
                        CommonStatusCodes.SUCCESS -> {
                            val smsContent = extras.getString(SmsRetriever.EXTRA_SMS_MESSAGE)
                            if (smsContent != null) {
                                ignoreIllegalState {
                                    consumeSmsResult()?.invoke(
                                        Result.success(smsContent)
                                    )
                                }
                            } else {
                                val message =
                                    "Retrieved SMS is null, check if SMS contains correct app signature"
                                Log.e(PLUGIN_TAG, message)
                                ignoreIllegalState {
                                    consumeSmsResult()?.invoke(Result.failure(Exception(message)))
                                }
                            }
                        }

                        CommonStatusCodes.TIMEOUT -> {
                            val message =
                                "SMS Retriever API timed out, check if SMS contains correct app signature"
                            Log.e(PLUGIN_TAG, message)
                            ignoreIllegalState {
                                consumeSmsResult()?.invoke(Result.failure(Exception(message)))
                            }
                        }

                        else -> {
                            val message =
                                "SMS Retriever API failed with status code: ${smsRetrieverStatus.statusCode}, check if SMS contains correct app signature"
                            Log.e(PLUGIN_TAG, message)
                            ignoreIllegalState {
                                consumeSmsResult()?.invoke(Result.failure(Exception(message)))
                            }
                        }
                    }
                } else {
                    val message =
                        "SMS Retriever API failed with no status code, check if SMS contains correct app signature"
                    Log.e(PLUGIN_TAG, message)
                    ignoreIllegalState {
                        consumeSmsResult()?.invoke(Result.failure(Exception(message)))
                    }
                }
            }
        }
    }

    /**
     * SMS User Consent API
     * [https://developers.google.com/identity/sms-retriever/user-consent/overview]
     */
    inner class ConsentBroadcastReceiver : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (SmsRetriever.SMS_RETRIEVED_ACTION == intent.action) {
                unregisterConsentReceiver()
                if (intent.extras != null && intent.extras!!.containsKey(SmsRetriever.EXTRA_STATUS)) {
                    val extras = intent.extras!!
                    val smsRetrieverStatus = extras.get(SmsRetriever.EXTRA_STATUS) as Status
                    when (smsRetrieverStatus.statusCode) {
                        CommonStatusCodes.SUCCESS -> {
                            try {
                                val consentIntent =
                                    extras.getParcelable<Intent>(SmsRetriever.EXTRA_CONSENT_INTENT)

                                if (consentIntent != null && mActivity != null) {
                                    this@SmartAuthPlugin.mActivity?.startActivityForResult(
                                        consentIntent, USER_CONSENT_REQUEST
                                    )
                                } else {
                                    val message =
                                        "ConsentBroadcastReceiver error: Can't start consent intent. consentIntent or mActivity is null"
                                    Log.e(PLUGIN_TAG, message)
                                    ignoreIllegalState {
                                        consumeSmsResult()?.invoke(Result.failure(Exception(message)))
                                    }
                                }
                            } catch (e: ActivityNotFoundException) {
                                val message = "ConsentBroadcastReceiver error: $e"
                                Log.e(PLUGIN_TAG, message)
                                ignoreIllegalState {
                                    consumeSmsResult()?.invoke(Result.failure(Exception(message)))
                                }
                            }
                        }

                        CommonStatusCodes.TIMEOUT -> {
                            val message = "ConsentBroadcastReceiver Timeout"
                            Log.e(PLUGIN_TAG, message)
                            ignoreIllegalState {
                                consumeSmsResult()?.invoke(Result.failure(Exception(message)))
                            }
                        }

                        else -> {
                            val message =
                                "ConsentBroadcastReceiver failed with status code: ${smsRetrieverStatus.statusCode}"
                            Log.e(PLUGIN_TAG, message)
                            ignoreIllegalState {
                                consumeSmsResult()?.invoke(Result.failure(Exception(message)))
                            }
                        }

                    }
                } else {
                    val message = "ConsentBroadcastReceiver failed with no status code"
                    Log.e(PLUGIN_TAG, message)
                    ignoreIllegalState {
                        consumeSmsResult()?.invoke(Result.failure(Exception(message)))
                    }

                }

            }
        }
    }


    companion object {
        private const val PLUGIN_TAG = "Pinput/SmartAuth"
        private const val PHONE_NUMBER_HINT_REQUEST = 11100
        private const val USER_CONSENT_REQUEST = 11101
    }
}
