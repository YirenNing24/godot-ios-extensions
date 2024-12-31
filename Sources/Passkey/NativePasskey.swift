import Foundation
import AuthenticationServices
import SwiftGodot

class NativePasskey: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    weak var delegate: PasskeyDelegate?

    private var authorizationController: ASAuthorizationController?

    func initiateSignInWithPasskey(requestJson: String) {
        guard let requestData = requestJson.data(using: .utf8) else {
            delegate?.didEncounterError("Invalid JSON data")
            return
        }

        do {
            // Decode JSON into a Dictionary or a custom struct (ASAuthorizationPlatformPublicKeyCredentialDescriptor is not Decodable)
            let json = try JSONSerialization.jsonObject(with: requestData, options: [])
            guard let credentialRequest = json as? [String: Any] else {
                delegate?.didEncounterError("Invalid JSON structure")
                return
            }
            
            // Assuming you have the necessary values (e.g., challenge, name, userID) from the JSON
            guard let challengeData = credentialRequest["challenge"] as? Data,
                  let userIDData = credentialRequest["userID"] as? Data,
                  let name = credentialRequest["name"] as? String else {
                delegate?.didEncounterError("Missing required fields in JSON")
                return
            }

            let provider = ASAuthorizationPlatformPublicKeyCredentialProvider()
            let request = provider.createCredentialAssertionRequest(challenge: challengeData, name: name, userID: userIDData)

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
            // Decode JSON into a Dictionary or a custom struct (ASAuthorizationPlatformPublicKeyCredentialDescriptor is not Decodable)
            let json = try JSONSerialization.jsonObject(with: requestData, options: [])
            guard let descriptor = json as? [String: Any] else {
                delegate?.didEncounterError("Invalid JSON structure")
                return
            }

            // Assuming you have the necessary values (e.g., challenge, name, userID) from the JSON
            guard let challengeData = descriptor["challenge"] as? Data,
                  let userIDData = descriptor["userID"] as? Data,
                  let name = descriptor["name"] as? String else {
                delegate?.didEncounterError("Missing required fields in JSON")
                return
            }

            let provider = ASAuthorizationPlatformPublicKeyCredentialProvider()
            let registrationRequest = provider.createCredentialRegistrationRequest(challenge: challengeData, name: name, userID: userIDData)

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
        if let credential = authorization.credential as? ASPublicKeyCredential {
            let clientData = credential.rawClientDataJSON
            if let responseJson = String(data: clientData, encoding: .utf8) {
                delegate?.didCompleteWithSuccess(responseJson)
            } else {
                delegate?.didEncounterError("Failed to decode client data into a string")
            }
        } else {
            delegate?.didEncounterError("Invalid credential type")
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
