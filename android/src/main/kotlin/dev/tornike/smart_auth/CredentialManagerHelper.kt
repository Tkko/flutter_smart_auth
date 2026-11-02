package dev.tornike.smart_auth

import android.app.Activity
import android.content.Context
import android.os.Build
import androidx.credentials.ClearCredentialStateRequest
import androidx.credentials.CreateCredentialRequest
import androidx.credentials.CreateCredentialResponse
import androidx.credentials.CreatePasswordRequest
import androidx.credentials.CreatePasswordResponse
import androidx.credentials.CreatePublicKeyCredentialRequest
import androidx.credentials.CreatePublicKeyCredentialResponse
import androidx.credentials.Credential
import androidx.credentials.CredentialManager
import androidx.credentials.GetCredentialRequest
import androidx.credentials.GetPasswordOption
import androidx.credentials.GetPublicKeyCredentialOption
import androidx.credentials.PasswordCredential
import androidx.credentials.PrepareGetCredentialResponse
import androidx.credentials.PublicKeyCredential
import androidx.credentials.exceptions.ClearCredentialException
import androidx.credentials.exceptions.CreateCredentialCancellationException
import androidx.credentials.exceptions.CreateCredentialException
import androidx.credentials.exceptions.GetCredentialCancellationException
import androidx.credentials.exceptions.GetCredentialException
import androidx.credentials.exceptions.NoCredentialException

/**
 * Wraps the Android Credential Manager
 * [https://developer.android.com/identity/sign-in/credential-manager]
 */
class CredentialManagerHelper(context: Context) {
    private val credentialManager = CredentialManager.create(context)
    private var preparedResponse: PrepareGetCredentialResponse? = null

    /**
     * Incremented whenever a preparation starts or the prepared state is
     * invalidated, so a preparation that finishes late can't restore a cleared
     * or older request.
     */
    private var prepareGeneration = 0

    suspend fun getCredential(
        activity: Activity?, request: SmartAuthGetCredentialRequest
    ): SmartAuthCredential {
        val currentActivity = requireActivity(activity)
        try {
            val response = credentialManager.getCredential(currentActivity, buildGetRequest(request))
            return response.credential.toMessage()
        } catch (e: GetCredentialCancellationException) {
            throw canceled("GET_CREDENTIAL_CANCELED", "User canceled get credential request.")
        } catch (e: NoCredentialException) {
            throw FlutterError("NO_CREDENTIAL", e.message ?: "No credential found", null)
        } catch (e: GetCredentialException) {
            throw FlutterError("GET_CREDENTIAL_FAILED", e.message, e.type)
        }
    }

    suspend fun createCredential(
        activity: Activity?, request: SmartAuthCreateCredentialRequest
    ): SmartAuthCreateCredentialResponse {
        val currentActivity = requireActivity(activity)
        try {
            val response = credentialManager.createCredential(
                currentActivity, buildCreateRequest(request)
            )
            return response.toMessage()
        } catch (e: CreateCredentialCancellationException) {
            throw canceled("CREATE_CREDENTIAL_CANCELED", "User canceled create credential request.")
        } catch (e: CreateCredentialException) {
            throw FlutterError("CREATE_CREDENTIAL_FAILED", e.message, e.type)
        }
    }

    suspend fun prepareGetCredential(
        request: SmartAuthGetCredentialRequest
    ): SmartAuthPreparedCredential {
        requireUpsideDownCake("prepareGetCredential")
        val generation = ++prepareGeneration
        preparedResponse = null
        try {
            val response = credentialManager.prepareGetCredential(buildGetRequest(request))
            if (generation != prepareGeneration) {
                throw canceled(
                    "PREPARE_GET_CREDENTIAL_CANCELED",
                    "Prepare request was replaced or cleared before it finished."
                )
            }
            preparedResponse = response
            return SmartAuthPreparedCredential(
                hasPasswordCredentials = queryResults {
                    response.hasCredentialResults(PasswordCredential.TYPE_PASSWORD_CREDENTIAL)
                },
                hasPublicKeyCredentials = queryResults {
                    response.hasCredentialResults(PublicKeyCredential.TYPE_PUBLIC_KEY_CREDENTIAL)
                },
                hasAuthenticationResults = queryResults { response.hasAuthenticationResults() },
                hasRemoteResults = queryResults { response.hasRemoteResults() },
            )
        } catch (e: GetCredentialException) {
            throw FlutterError("PREPARE_GET_CREDENTIAL_FAILED", e.message, e.type)
        }
    }

    suspend fun getPreparedCredential(activity: Activity?): SmartAuthCredential {
        val currentActivity = requireActivity(activity)
        requireUpsideDownCake("getPreparedCredential")
        val response = preparedResponse ?: throw FlutterError(
            "NO_PREPARED_CREDENTIAL",
            "Call prepareGetCredential before getPreparedCredential.",
            null
        )
        val handle = response.pendingGetCredentialHandle
        preparedResponse = null
        if (handle == null) {
            throw FlutterError("NO_CREDENTIAL", "No prepared credentials available.", null)
        }
        try {
            val getResponse = credentialManager.getCredential(currentActivity, handle)
            return getResponse.credential.toMessage()
        } catch (e: GetCredentialCancellationException) {
            throw canceled("GET_CREDENTIAL_CANCELED", "User canceled get credential request.")
        } catch (e: NoCredentialException) {
            throw FlutterError("NO_CREDENTIAL", e.message ?: "No credential found", null)
        } catch (e: GetCredentialException) {
            throw FlutterError("GET_CREDENTIAL_FAILED", e.message, e.type)
        }
    }

    suspend fun clearCredentialState() {
        invalidatePrepared()
        try {
            credentialManager.clearCredentialState(ClearCredentialStateRequest())
        } catch (e: ClearCredentialException) {
            throw FlutterError("CLEAR_CREDENTIAL_STATE_FAILED", e.message, e.type)
        }
    }

    fun dispose() {
        invalidatePrepared()
    }

    private fun invalidatePrepared() {
        prepareGeneration++
        preparedResponse = null
    }

    private fun buildGetRequest(request: SmartAuthGetCredentialRequest): GetCredentialRequest {
        val options = mutableListOf<androidx.credentials.CredentialOption>()
        request.passwordOption?.let {
            options.add(
                GetPasswordOption(
                    allowedUserIds = it.allowedUserIds?.toSet() ?: emptySet(),
                    isAutoSelectAllowed = it.isAutoSelectAllowed ?: false,
                )
            )
        }
        request.publicKeyOptions?.forEach {
            options.add(GetPublicKeyCredentialOption(it.requestJson, it.clientDataHash))
        }
        if (options.isEmpty()) {
            throw FlutterError(
                "INVALID_REQUEST", "At least one credential option must be provided.", null
            )
        }
        return GetCredentialRequest(
            credentialOptions = options,
            origin = request.origin,
            preferImmediatelyAvailableCredentials =
                request.preferImmediatelyAvailableCredentials ?: false,
        )
    }

    private fun buildCreateRequest(request: SmartAuthCreateCredentialRequest): CreateCredentialRequest {
        return when (request.type) {
            SmartAuthCredentialType.PASSWORD -> CreatePasswordRequest(
                id = request.id ?: throw invalid("id is required to create a password credential"),
                password = request.password
                    ?: throw invalid("password is required to create a password credential"),
                origin = request.origin,
                preferImmediatelyAvailableCredentials =
                    request.preferImmediatelyAvailableCredentials ?: false,
                isAutoSelectAllowed = request.isAutoSelectAllowed ?: false,
            )

            SmartAuthCredentialType.PUBLIC_KEY -> CreatePublicKeyCredentialRequest(
                requestJson = request.requestJson
                    ?: throw invalid("requestJson is required to create a passkey"),
                clientDataHash = request.clientDataHash,
                preferImmediatelyAvailableCredentials =
                    request.preferImmediatelyAvailableCredentials ?: false,
                origin = request.origin,
            )

            SmartAuthCredentialType.UNKNOWN -> throw invalid("Unsupported credential type")
        }
    }

    private fun Credential.toMessage(): SmartAuthCredential = when (this) {
        is PasswordCredential -> SmartAuthCredential(
            type = SmartAuthCredentialType.PASSWORD, id = id, password = password
        )

        is PublicKeyCredential -> SmartAuthCredential(
            type = SmartAuthCredentialType.PUBLIC_KEY,
            authenticationResponseJson = authenticationResponseJson,
        )

        else -> SmartAuthCredential(type = SmartAuthCredentialType.UNKNOWN)
    }

    private fun CreateCredentialResponse.toMessage(): SmartAuthCreateCredentialResponse =
        when (this) {
            is CreatePublicKeyCredentialResponse -> SmartAuthCreateCredentialResponse(
                type = SmartAuthCredentialType.PUBLIC_KEY,
                registrationResponseJson = registrationResponseJson,
            )

            is CreatePasswordResponse -> SmartAuthCreateCredentialResponse(
                type = SmartAuthCredentialType.PASSWORD
            )

            else -> SmartAuthCreateCredentialResponse(type = SmartAuthCredentialType.UNKNOWN)
        }

    /**
     * Only privileged apps may query the prepared results, other apps get a
     * SecurityException, which is reported as null (unknown).
     */
    private fun queryResults(query: () -> Boolean): Boolean? = try {
        query()
    } catch (e: SecurityException) {
        null
    }

    private fun requireActivity(activity: Activity?): Activity =
        activity ?: throw FlutterError(
            "NO_ACTIVITY", "Credential Manager requires a foreground activity.", null
        )

    private fun requireUpsideDownCake(method: String) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            throw FlutterError(
                "UNSUPPORTED", "$method requires Android 14 (API 34) or higher.", null
            )
        }
    }

    private fun invalid(message: String) = FlutterError("INVALID_REQUEST", message, null)

    private fun canceled(code: String, message: String) =
        FlutterError(code, message, SmartAuthRequestCanceled())
}
