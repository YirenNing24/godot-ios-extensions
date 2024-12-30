import SwiftGodot
import AuthenticationServices

#initSwiftExtension(
    cdecl: "swift_entry_point",
    types: [Passkey.self]
)

@Godot
class Passkey: RefCounted {
    private var authorizationController: ASAuthorizationController?

    // Define signals for Godot to listen to
    #signal("sign_in_completed", arguments: ["responseJson": String.self])
    #signal("sign_in_error", arguments: ["errorMessage": String.self])
    #signal("create_passkey_completed", arguments: ["responseJson": String.self])
    #signal("create_passkey_error", arguments: ["errorMessage": String.self])

    @Callable
    func initiateSignInWithPasskey(requestJson: String) {
        guard let requestData = requestJson.data(using: .utf8) else {
            emit(signal: Passkey.sign_in_error, "Invalid JSON data")
            return
        }

        do {
            // Decode the JSON to construct the required descriptor
            let credentialRequest = try JSONDecoder().decode(ASAuthorizationPlatformPublicKeyCredentialDescriptor.self, from: requestData)
            
            let request = ASAuthorizationPlatformPublicKeyCredentialProvider().createCredentialAssertionRequest(descriptor: credentialRequest)

            self.authorizationController = ASAuthorizationController(authorizationRequests: [request])
            self.authorizationController?.delegate = self
            self.authorizationController?.presentationContextProvider = self
            self.authorizationController?.performRequests()

        } catch {
            emit(signal: Passkey.sign_in_error, "Failed to parse request JSON: \(error.localizedDescription)")
        }
    }

    @Callable
    func createPasskey(requestJson: String) {
        guard let requestData = requestJson.data(using: .utf8) else {
            emit(signal: Passkey.create_passkey_error, "Invalid JSON data")
            return
        }

        do {
            // Decode the JSON to construct the required descriptor
            let descriptor = try JSONDecoder().decode(ASAuthorizationPlatformPublicKeyCredentialDescriptor.self, from: requestData)

            let registrationRequest = ASAuthorizationPlatformPublicKeyCredentialProvider().createCredentialRegistrationRequest(descriptor: descriptor)

            self.authorizationController = ASAuthorizationController(authorizationRequests: [registrationRequest])
            self.authorizationController?.delegate = self
            self.authorizationController?.presentationContextProvider = self
            self.authorizationController?.performRequests()

        } catch {
            emit(signal: Passkey.create_passkey_error, "Failed to parse request JSON: \(error.localizedDescription)")
        }
    }
}

// MARK: - ASAuthorizationControllerDelegate
extension Passkey: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let credential = authorization.credential as? ASAuthorizationPlatformPublicKeyCredential {
            if let credentialData = credential.rawCredential,
               let responseJson = String(data: credentialData, encoding: .utf8) {
                emit(signal: Passkey.sign_in_completed, responseJson)
            } else {
                emit(signal: Passkey.sign_in_error, "Failed to decode credential data")
            }
        } else {
            emit(signal: Passkey.sign_in_error, "Unexpected credential type")
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        emit(signal: Passkey.sign_in_error, error.localizedDescription)
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding
extension Passkey: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return UIApplication.shared.windows.first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}
