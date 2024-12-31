import Foundation
import AuthenticationServices

class NativePasskey: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    weak var delegate: PasskeyDelegate?

    private var authorizationController: ASAuthorizationController?

    func initiateSignInWithPasskey(requestJson: String) {
        guard let requestData = requestJson.data(using: .utf8) else {
            delegate?.didEncounterError("Invalid JSON data")
            return
        }

        do {
            let credentialRequest = try JSONDecoder().decode(ASAuthorizationPlatformPublicKeyCredentialDescriptor.self, from: requestData)
            let request = ASAuthorizationPlatformPublicKeyCredentialProvider().createCredentialAssertionRequest(descriptor: credentialRequest)

            authorizationController = ASAuthorizationController(authorizationRequests: [request])
            authorizationController?.delegate = self
            authorizationController?.presentationContextProvider = self
            authorizationController?.performRequests()

        } catch {
            delegate?.didEncounterError("Failed to parse request JSON: \(error.localizedDescription)")
        }
    }

    func createPasskey(requestJson: String) {
        guard let requestData = requestJson.data(using: .utf8) else {
            delegate?.didEncounterError("Invalid JSON data")
            return
        }

        do {
            let descriptor = try JSONDecoder().decode(ASAuthorizationPlatformPublicKeyCredentialDescriptor.self, from: requestData)
            let registrationRequest = ASAuthorizationPlatformPublicKeyCredentialProvider().createCredentialRegistrationRequest(descriptor: descriptor)

            authorizationController = ASAuthorizationController(authorizationRequests: [registrationRequest])
            authorizationController?.delegate = self
            authorizationController?.presentationContextProvider = self
            authorizationController?.performRequests()

        } catch {
            delegate?.didEncounterError("Failed to parse request JSON: \(error.localizedDescription)")
        }
    }

    // MARK: - ASAuthorizationControllerDelegate
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let credential = authorization.credential as? ASAuthorizationPlatformPublicKeyCredential,
           let credentialData = credential.rawCredential,
           let responseJson = String(data: credentialData, encoding: .utf8) {
            delegate?.didCompleteWithSuccess(responseJson)
        } else {
            delegate?.didEncounterError("Failed to decode credential data")
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        delegate?.didEncounterError(error.localizedDescription)
    }

    // MARK: - ASAuthorizationControllerPresentationContextProviding
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return UIApplication.shared.windows.first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}

// Delegate protocol for communication with Godot class
protocol PasskeyDelegate: AnyObject {
    func didCompleteWithSuccess(_ responseJson: String)
    func didEncounterError(_ errorMessage: String)
}
