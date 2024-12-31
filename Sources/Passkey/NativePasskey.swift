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
            // Decode the JSON into a dictionary
            let json = try JSONSerialization.jsonObject(with: requestData, options: []) as? [String: Any]
            guard let challengeBase64 = json?["challenge"] as? String,
                  let challengeData = Data(base64Encoded: challengeBase64) else {
                delegate?.didEncounterError("Invalid or missing challenge in JSON")
                return
            }

            // Use the challenge to create the credential assertion request
            let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: "your.relying.party.identifier")
            let assertionRequest = provider.createCredentialAssertionRequest(challenge: challengeData)

            authorizationController = ASAuthorizationController(authorizationRequests: [assertionRequest])
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
            // Decode the JSON into a dictionary
            let json = try JSONSerialization.jsonObject(with: requestData, options: []) as? [String: Any]
            guard let challengeBase64 = json?["challenge"] as? String,
                  let challengeData = Data(base64Encoded: challengeBase64),
                  let userIDBase64 = json?["userID"] as? String,
                  let userIDData = Data(base64Encoded: userIDBase64),
                  let userName = json?["name"] as? String else {
                delegate?.didEncounterError("Invalid or missing fields in JSON")
                return
            }

            // Use the parsed data to create the credential registration request
            let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: "your.relying.party.identifier")
            let registrationRequest = provider.createCredentialRegistrationRequest(challenge: challengeData, name: userName, userID: userIDData)

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
