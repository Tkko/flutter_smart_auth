package fman.ge.smart_auth

import android.app.Activity
import android.app.Activity.RESULT_OK
import android.content.*
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


/** SmartAuthPlugin */
class SmartAuthPlugin : FlutterPlugin, ActivityAware, PluginRegistry.ActivityResultListener,
    SmartAuthApi {
    private lateinit var mContext: Context
    private var mActivity: Activity? = null
    private var mBinding: ActivityPluginBinding? = null
    private var pendingResult: ((Result<String>) -> Unit)? = null
    private var smsReceiver: SmsBroadcastReceiver? = null
    private var consentReceiver: ConsentBroadcastReceiver? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        mContext = flutterPluginBinding.applicationContext
        SmartAuthApi.setUp(flutterPluginBinding.binaryMessenger, this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        dispose()
    }

    override fun onDetachedFromActivity() = dispose()

    override fun onDetachedFromActivityForConfigChanges() = dispose()


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


    override fun getSmsWithRetrieverApi(callback: (Result<String>) -> Unit) {
        unregisterAllReceivers()
        pendingResult = callback
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

    override fun getSmsWithUserConsentApi(
        phoneNumber: String?, callback: (Result<String>) -> Unit
    ) {
        unregisterAllReceivers()
        pendingResult = callback
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


    override fun removeSmsRetrieverListener() {
        if (smsReceiver != null) {
            unregisterReceiver(smsReceiver)
            smsReceiver = null
        }
    }

    override fun removeUserConsentListener() {
        if (consentReceiver != null) {
            unregisterReceiver(consentReceiver)
            consentReceiver = null
        }
    }


    override fun requestPhoneNumberHint(callback: (Result<String>) -> Unit) {
        pendingResult = callback
        val hintRequest = GetPhoneNumberHintIntentRequest.builder().build()

        val signInClient = Identity.getSignInClient(mContext)
        signInClient.getPhoneNumberHintIntent(hintRequest).addOnSuccessListener { pendingIntent ->
            if (mActivity != null) {
                startIntentSenderForResult(
                    mActivity!!,
                    pendingIntent.intentSender,
                    PHONE_NUMBER_HINT_REQUEST,
                    null,
                    0,
                    0,
                    0,
                    null
                )
            }
        }.addOnFailureListener { exception ->
            val message = "Failed to get phone number hint intent: ${exception.message}"
            Log.e(PLUGIN_TAG, message)
            callback.invoke(Result.failure(Exception(message)))
        }
    }

    /// Callbacks
    private fun onSmsConsentRequest(resultCode: Int, data: Intent?) {
        if (resultCode == RESULT_OK && data != null) {
            val message = data.getStringExtra(SmsRetriever.EXTRA_SMS_MESSAGE)
            if (message == null) {
                ignoreIllegalState {
                    pendingResult?.invoke(
                        Result.failure(
                            Exception("Failed to get SMS with user consent.")
                        )
                    )
                }
                return
            }
            ignoreIllegalState { pendingResult?.invoke(Result.success(message)) }
        } else {
            ignoreIllegalState {
                pendingResult?.invoke(
                    Result.failure(
                        Exception("Failed to get SMS with user consent.")
                    )
                )
            }
        }
    }

    private fun onPhoneNumberHintRequest(resultCode: Int, data: Intent?) {
        if (resultCode == RESULT_OK && data != null) {
            val phoneNumber = Identity.getSignInClient(mContext).getPhoneNumberFromIntent(data)
            ignoreIllegalState {
                pendingResult?.invoke(Result.success(phoneNumber))
            }
            return
        }

        val message = "Failed to get phone number hint."
        Log.e(PLUGIN_TAG, message)
        ignoreIllegalState {
            pendingResult?.invoke(Result.failure(Exception(message)))
        }
    }


    private fun dispose() {
        unregisterAllReceivers()
        mActivity = null
        mBinding?.removeActivityResultListener(this)
        mBinding = null
    }

    private fun unregisterAllReceivers() {
        removeSmsRetrieverListener();
        removeUserConsentListener();
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
                removeSmsRetrieverListener()
                if (intent.extras != null && intent.extras!!.containsKey(SmsRetriever.EXTRA_STATUS)) {
                    val extras = intent.extras!!
                    val smsRetrieverStatus = extras.get(SmsRetriever.EXTRA_STATUS) as Status
                    when (smsRetrieverStatus.statusCode) {
                        CommonStatusCodes.SUCCESS -> {
                            val smsContent = extras.getString(SmsRetriever.EXTRA_SMS_MESSAGE)
                            if (smsContent != null) {
                                ignoreIllegalState {
                                    pendingResult?.invoke(
                                        Result.success(smsContent)
                                    )
                                }
                            } else {
                                val message =
                                    "Retrieved SMS is null, check if SMS contains correct app signature"
                                Log.e(PLUGIN_TAG, message)
                                ignoreIllegalState {
                                    pendingResult?.invoke(Result.failure(Exception(message)))
                                }
                            }
                        }

                        CommonStatusCodes.TIMEOUT -> {
                            val message =
                                "SMS Retriever API timed out, check if SMS contains correct app signature"
                            Log.e(PLUGIN_TAG, message)
                            ignoreIllegalState {
                                pendingResult?.invoke(Result.failure(Exception(message)))
                            }
                        }

                        else -> {
                            val message =
                                "SMS Retriever API failed with status code: ${smsRetrieverStatus.statusCode}, check if SMS contains correct app signature"
                            Log.e(PLUGIN_TAG, message)
                            ignoreIllegalState {
                                pendingResult?.invoke(Result.failure(Exception(message)))
                            }
                        }
                    }
                } else {
                    val message =
                        "SMS Retriever API failed with no status code, check if SMS contains correct app signature"
                    Log.e(PLUGIN_TAG, message)
                    ignoreIllegalState {
                        pendingResult?.invoke(Result.failure(Exception(message)))
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
                removeUserConsentListener()
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
                                        pendingResult?.invoke(Result.failure(Exception(message)))
                                    }
                                }
                            } catch (e: ActivityNotFoundException) {
                                val message = "ConsentBroadcastReceiver error: $e"
                                Log.e(PLUGIN_TAG, message)
                                ignoreIllegalState {
                                    pendingResult?.invoke(Result.failure(Exception(message)))
                                }
                            }
                        }

                        CommonStatusCodes.TIMEOUT -> {
                            val message = "ConsentBroadcastReceiver Timeout"
                            Log.e(PLUGIN_TAG, message)
                            ignoreIllegalState {
                                pendingResult?.invoke(Result.failure(Exception(message)))
                            }
                        }

                        else -> {
                            val message =
                                "ConsentBroadcastReceiver failed with status code: ${smsRetrieverStatus.statusCode}"
                            Log.e(PLUGIN_TAG, message)
                            ignoreIllegalState {
                                pendingResult?.invoke(Result.failure(Exception(message)))
                            }
                        }

                    }
                } else {
                    val message = "ConsentBroadcastReceiver failed with no status code"
                    Log.e(PLUGIN_TAG, message)
                    ignoreIllegalState {
                        pendingResult?.invoke(Result.failure(Exception(message)))
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
