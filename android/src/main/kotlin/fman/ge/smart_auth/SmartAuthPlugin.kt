package fman.ge.smart_auth

import android.app.Activity
import android.app.Activity.RESULT_OK
import android.app.PendingIntent
import android.content.*
import android.content.ContentValues.TAG
import android.net.Uri
import android.util.Log
import androidx.annotation.NonNull
import androidx.annotation.Nullable
import androidx.core.app.ActivityCompat.startIntentSenderForResult
import com.google.android.gms.auth.api.credentials.*
import com.google.android.gms.auth.api.credentials.HintRequest.Builder
import com.google.android.gms.auth.api.phone.SmsRetriever
import com.google.android.gms.common.ConnectionResult.RESOLUTION_REQUIRED
import com.google.android.gms.common.api.CommonStatusCodes
import com.google.android.gms.common.api.ResolvableApiException
import com.google.android.gms.common.api.Status
import com.google.android.gms.tasks.OnCompleteListener
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.PluginRegistry
import kotlin.collections.HashMap


/** SmartAuthPlugin */

class SmartAuthPlugin : FlutterPlugin, MethodCallHandler, ActivityAware,
    PluginRegistry.ActivityResultListener {
    private lateinit var mContext: Context
    private var mActivity: Activity? = null
    private var mBinding: ActivityPluginBinding? = null
    private var mChannel: MethodChannel? = null
    private var pendingResult: MethodChannel.Result? = null
    private var smsReceiver: SmsBroadcastReceiver? = null
    private var consentReceiver: ConsentBroadcastReceiver? = null

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        mChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "fman.smart_auth")
        mContext = flutterPluginBinding.applicationContext
        mChannel?.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        dispose()
        mChannel?.setMethodCallHandler(null)
        mChannel = null
    }

    override fun onDetachedFromActivity() = dispose()

    override fun onDetachedFromActivityForConfigChanges() = dispose()


    private fun dispose() {
        unregisterReceiver(smsReceiver)
        unregisterReceiver(consentReceiver)
        smsReceiver = null
        consentReceiver = null
        ignoreIllegalState { pendingResult?.success(null) }
        mActivity = null
        mBinding?.removeActivityResultListener(this)
        mBinding = null
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

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getAppSignature" -> getSignature(result)
            "startSmsRetriever" -> startSmsRetriever(result)
            "startSmsUserConsent" -> startSmsUserConsent(call, result)
            "stopSmsRetriever" -> stopSmsRetriever(result)
            "stopSmsUserConsent" -> stopSmsUserConsent(result)
            "requestHint" -> requestHint(call, result)
            "saveCredential" -> saveCredential(call, result)
            "deleteCredential" -> deleteCredential(call, result)
            "getCredential" -> getCredential(call, result)
            else -> result.notImplemented()
        }
    }

    override fun onActivityResult(
        requestCode: Int,
        resultCode: Int,
        @Nullable data: Intent?
    ): Boolean {
        when (requestCode) {
            HINT_REQUEST -> onHintRequest(resultCode, data)
            USER_CONSENT_REQUEST -> onSmsConsentRequest(resultCode, data)
            SAVE_CREDENTIAL_REQUEST -> onSaveCredentialRequest(resultCode)
            GET_CREDENTIAL_REQUEST -> onGetCredentialRequest(resultCode, data)
        }
        return true
    }


    private fun getSignature(result: MethodChannel.Result) {
        val signatures = AppSignatureHelper(mContext).getAppSignatures()
        result.success(signatures.getOrNull(0))
    }


    private fun requestHint(call: MethodCall, result: MethodChannel.Result) {
        pendingResult = result

        val showAddAccountButton = call.argument<Boolean?>("showAddAccountButton")
        val showCancelButton = call.argument<Boolean?>("showCancelButton")
        val isPhoneNumberIdentifierSupported =
            call.argument<Boolean?>("isPhoneNumberIdentifierSupported")
        val isEmailAddressIdentifierSupported =
            call.argument<Boolean?>("isEmailAddressIdentifierSupported")
        val accountTypes = call.argument<String?>("accountTypes")
        val idTokenNonce = call.argument<String?>("idTokenNonce")
        val isIdTokenRequested = call.argument<Boolean?>("isIdTokenRequested")
        val serverClientId = call.argument<String?>("serverClientId")

        val hintRequest = Builder()
        val config = CredentialPickerConfig.Builder()

        if (showAddAccountButton != null)
            config.setShowAddAccountButton(showAddAccountButton)

        if (showCancelButton != null)
            config.setShowCancelButton(showCancelButton)

        hintRequest.setHintPickerConfig(config.build())

        if (isPhoneNumberIdentifierSupported != null)
            hintRequest.setPhoneNumberIdentifierSupported(isPhoneNumberIdentifierSupported)

        if (isEmailAddressIdentifierSupported != null)
            hintRequest.setEmailAddressIdentifierSupported(isEmailAddressIdentifierSupported)

        if (accountTypes != null)
            hintRequest.setAccountTypes(accountTypes)

        if (idTokenNonce != null)
            hintRequest.setIdTokenNonce(idTokenNonce)

        if (isIdTokenRequested != null)
            hintRequest.setIdTokenRequested(isIdTokenRequested)

        if (serverClientId != null)
            hintRequest.setServerClientId(serverClientId)


        val intent: PendingIntent =
            Credentials.getClient(mContext).getHintPickerIntent(hintRequest.build())

        if (mActivity != null) {
            startIntentSenderForResult(
                mActivity!!,
                intent.intentSender,
                HINT_REQUEST,
                null,
                0,
                0,
                0,
                null
            )
        }
    }


    private fun saveCredential(call: MethodCall, result: MethodChannel.Result) {
        val credential = maybeBuildCredential(call, result) ?: return

        val mCredentialsClient = Credentials.getClient(mContext)
        mCredentialsClient.save(credential).addOnCompleteListener { task ->
            if (task.isSuccessful) {
                result.success(true)
                return@addOnCompleteListener
            }
            val exception = task.exception
            if (exception is ResolvableApiException && exception.statusCode == RESOLUTION_REQUIRED && mActivity != null) {
                try {
                    pendingResult = result
                    exception.startResolutionForResult(
                        mActivity as Activity,
                        SAVE_CREDENTIAL_REQUEST
                    )
                    return@addOnCompleteListener
                } catch (exception: IntentSender.SendIntentException) {
                    Log.e(TAG, "Failed to send resolution.", exception)
                }
            }
            result.success(false)
        }

    }

    private fun getCredential(call: MethodCall, result: MethodChannel.Result) {
        val accountType = call.argument<String?>("accountType")
        val serverClientId = call.argument<String?>("serverClientId")
        val idTokenNonce = call.argument<String?>("idTokenNonce")
        val isIdTokenRequested = call.argument<Boolean?>("isIdTokenRequested")
        val isPasswordLoginSupported = call.argument<Boolean?>("isPasswordLoginSupported")
        val showResolveDialog = call.argument<Boolean?>("showResolveDialog") ?: false


        val credentialRequest = CredentialRequest.Builder().setAccountTypes(accountType)
        if (accountType != null)
            credentialRequest.setAccountTypes(accountType)
        if (idTokenNonce != null)
            credentialRequest.setIdTokenNonce(idTokenNonce)
        if (isIdTokenRequested != null)
            credentialRequest.setIdTokenRequested(isIdTokenRequested)
        if (isPasswordLoginSupported != null)
            credentialRequest.setPasswordLoginSupported(isPasswordLoginSupported)
        if (serverClientId != null)
            credentialRequest.setServerClientId(serverClientId)


        val credentialsClient: CredentialsClient = Credentials.getClient(mContext)
        credentialsClient.request(credentialRequest.build()).addOnCompleteListener(
            OnCompleteListener { task ->
                if (task.isSuccessful && task.result != null && task.result.credential != null) {
                    val credential: Credential? = task.result!!.credential
                    if (credential != null) {
                        result.success(credentialToMap(credential))
                        return@OnCompleteListener
                    }
                }

                val exception = task.exception
                if (exception is ResolvableApiException && exception.statusCode == RESOLUTION_REQUIRED && mActivity != null && showResolveDialog) {
                    try {
                        pendingResult = result
                        exception.startResolutionForResult(
                            mActivity as Activity,
                            GET_CREDENTIAL_REQUEST,
                        )
                        return@OnCompleteListener
                    } catch (exception: IntentSender.SendIntentException) {
                        Log.e(TAG, "Failed to send resolution.", exception)
                    }
                }

                result.success(null)
                return@OnCompleteListener
            })
    }


    private fun deleteCredential(call: MethodCall, result: MethodChannel.Result) {
        val credential = maybeBuildCredential(call, result) ?: return
        val mCredentialsClient: CredentialsClient = Credentials.getClient(mContext)
        mCredentialsClient.delete(credential).addOnCompleteListener { task ->
            result.success(task.isSuccessful)
        }
    }

    private fun startSmsRetriever(result: MethodChannel.Result) {
        if (smsReceiver != null) unregisterReceiver(smsReceiver)
        pendingResult = result
        smsReceiver = SmsBroadcastReceiver()
        mContext.registerReceiver(
            smsReceiver,
            IntentFilter(SmsRetriever.SMS_RETRIEVED_ACTION),
            SmsRetriever.SEND_PERMISSION,
            null,
        )
        SmsRetriever.getClient(mContext).startSmsRetriever()
    }

    private fun stopSmsRetriever(result: MethodChannel.Result) {
        if (smsReceiver == null) {
            result.success(false)
            return
        }
        removeSmsRetrieverListener()
        result.success(true)
    }

    private fun removeSmsRetrieverListener() {
        unregisterReceiver(smsReceiver)
        smsReceiver = null
    }

    private fun startSmsUserConsent(call: MethodCall, result: MethodChannel.Result) {
        if (consentReceiver != null) unregisterReceiver(consentReceiver)
        pendingResult = result
        consentReceiver = ConsentBroadcastReceiver()
        mContext.registerReceiver(
            consentReceiver,
            IntentFilter(SmsRetriever.SMS_RETRIEVED_ACTION),
            SmsRetriever.SEND_PERMISSION,
            null,
        )
        SmsRetriever.getClient(mContext).startSmsUserConsent(call.argument("senderPhoneNumber"))
    }


    private fun stopSmsUserConsent(result: MethodChannel.Result) {
        if (consentReceiver == null) {
            result.success(false)
            return
        }
        removeSmsUserConsentListener()
        result.success(true)
    }

    private fun removeSmsUserConsentListener() {
        unregisterReceiver(consentReceiver)
        consentReceiver = null
    }


    private fun onHintRequest(resultCode: Int, data: Intent?) {
        if (resultCode == RESULT_OK && data != null) {
            val credential: Credential? = data.getParcelableExtra(Credential.EXTRA_KEY)
            if (credential != null) {
                ignoreIllegalState { pendingResult?.success(credentialToMap(credential)) }
                return
            }
        }

        ignoreIllegalState { pendingResult?.success(null) }
    }

    private fun onSmsConsentRequest(resultCode: Int, data: Intent?) {
        if (resultCode == RESULT_OK && data != null) {
            val message = data.getStringExtra(SmsRetriever.EXTRA_SMS_MESSAGE)
            ignoreIllegalState { pendingResult?.success(message) }
        } else {
            ignoreIllegalState { pendingResult?.success(null) }
        }
    }


    private fun onSaveCredentialRequest(resultCode: Int) {
        ignoreIllegalState { pendingResult?.success(resultCode == RESULT_OK) }
    }

    private fun onGetCredentialRequest(resultCode: Int, data: Intent?) {
        if (resultCode == RESULT_OK && data != null) {
            val credential: Credential? = data.getParcelableExtra(Credential.EXTRA_KEY)
            if (credential != null) {
                ignoreIllegalState { pendingResult?.success(credentialToMap(credential)) }
                return
            }

        }
        ignoreIllegalState { pendingResult?.success(null) }
    }


    private fun credentialToMap(credential: Credential): HashMap<String, String?> {
        val r: HashMap<String, String?> = HashMap()
        r["accountType"] = credential.accountType
        r["familyName"] = credential.familyName
        r["givenName"] = credential.givenName
        r["id"] = credential.id
        r["name"] = credential.name
        r["password"] = credential.password
        r["profilePictureUri"] = credential.profilePictureUri.toString()
        return r
    }


    private fun maybeBuildCredential(call: MethodCall, result: MethodChannel.Result): Credential? {
        val accountType: String? = call.argument<String?>("accountType")
        val id: String? = call.argument<String?>("id")
        val name: String? = call.argument<String?>("name")
        val password: String? = call.argument<String?>("password")
        val profilePictureUri: String? = call.argument<String?>("profilePictureUri")

        if (id == null) {
            result.success(false)
            return null
        }

        val credential = Credential.Builder(id)
        if (accountType != null)
            credential.setAccountType(accountType)
        if (name != null)
            credential.setName(name)
        if (password != null)
            credential.setPassword(password)
        if (profilePictureUri != null)
            credential.setProfilePictureUri(Uri.parse(profilePictureUri))

        return credential.build()
    }


    private fun unregisterReceiver(receiver: BroadcastReceiver?) {
        try {
            receiver?.let { mContext.unregisterReceiver(it) }
        } catch (exception: Exception) {
            Log.e(TAG, "Unregistering receiver failed.", exception)
        }
    }

    private fun ignoreIllegalState(fn: () -> Unit) {
        try {
            fn()
        } catch (e: IllegalStateException) {
            Log.e(TAG, "ignoring exception: $e")
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

                val extras = intent.extras
                val smsRetrieverStatus = extras!!.get(SmsRetriever.EXTRA_STATUS) as Status

                when (smsRetrieverStatus.statusCode) {
                    CommonStatusCodes.SUCCESS -> {
                        val smsContent = extras.get(SmsRetriever.EXTRA_SMS_MESSAGE) as String
                        ignoreIllegalState { pendingResult?.success(smsContent) }
                    }

                    CommonStatusCodes.TIMEOUT -> {
                        ignoreIllegalState { pendingResult?.success(null) }
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
                removeSmsUserConsentListener()

                val extras = intent.extras
                val smsRetrieverStatus = extras!!.get(SmsRetriever.EXTRA_STATUS) as Status

                when (smsRetrieverStatus.statusCode) {
                    CommonStatusCodes.SUCCESS -> {
                        try {
                            val consentIntent =
                                extras.getParcelable<Intent>(SmsRetriever.EXTRA_CONSENT_INTENT)
                            this@SmartAuthPlugin.mActivity?.startActivityForResult(
                                consentIntent,
                                USER_CONSENT_REQUEST
                            )
                        } catch (e: ActivityNotFoundException) {
                            Log.e(TAG, "ConsentBroadcastReceiver $e")
                            ignoreIllegalState { pendingResult?.success(null) }
                        }

                    }
                    CommonStatusCodes.TIMEOUT -> {
                        Log.e(TAG, "ConsentBroadcastReceiver Timeout")
                        ignoreIllegalState { pendingResult?.success(null) }
                    }
                }
            }
        }
    }


    companion object {
        private const val HINT_REQUEST = 110101
        private const val USER_CONSENT_REQUEST = 110102
        private const val SAVE_CREDENTIAL_REQUEST = 110103
        private const val GET_CREDENTIAL_REQUEST = 110104
    }
}
