import SwiftGodot
import AuthenticationServices

// Initialize the Swift extension for Godot
@_cdecl("swift_entry_point")
func initSwiftExtension() {
    SwiftGodot.initialize(types: [Passkey.self])
}

// Define the Passkey class as a Godot extension
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
            let credentialRequest = try JSONDecoder().decode(ASAuthorizationPlatformPublicKeyCredentialDescriptor.self, from: requestData)
            let request = ASAuthorizationPlatformPublicKeyCredentialProvider().createCredentialAssertionRequest(descriptor: credentialRequest)

            self.authorizationController = ASAuthorizationController(authorizationRequests: [request])
            self.authorizationController?.delegate = PasskeyAuthorizationDelegate(parent: self)
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
            let descriptor = try JSONDecoder().decode(ASAuthorizationPlatformPublicKeyCredentialDescriptor.self, from: requestData)
            let registrationRequest = ASAuthorizationPlatformPublicKeyCredentialProvider().createCredentialRegistrationRequest(descriptor: descriptor)

            self.authorizationController = ASAuthorizationController(authorizationRequests: [registrationRequest])
            self.authorizationController?.delegate = PasskeyAuthorizationDelegate(parent: self)
            self.authorizationController?.presentationContextProvider = self
            self.authorizationController?.performRequests()

        } catch {
            emit(signal: Passkey.create_passkey_error, "Failed to parse request JSON: \(error.localizedDescription)")
        }
    }
}

// A wrapper delegate class that conforms to NSObjectProtocol
class PasskeyAuthorizationDelegate: NSObject, ASAuthorizationControllerDelegate {
    weak var parent: Passkey?

    init(parent: Passkey) {
        self.parent = parent
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let parent = parent else { return }

        if let credential = authorization.credential as? ASAuthorizationPlatformPublicKeyCredential {
            if let credentialData = credential.rawCredential,
               let responseJson = String(data: credentialData, encoding: .utf8) {
                parent.emit(signal: Passkey.sign_in_completed, responseJson)
            } else {
                parent.emit(signal: Passkey.sign_in_error, "Failed to decode credential data")
            }
        } else {
            parent.emit(signal: Passkey.sign_in_error, "Unexpected credential type")
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        parent?.emit(signal: Passkey.sign_in_error, error.localizedDescription)
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding
extension Passkey: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return UIApplication.shared.windows.first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}
