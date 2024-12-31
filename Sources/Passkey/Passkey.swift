import SwiftGodot

// Initialize the Swift extension for Godot
@_cdecl("swift_entry_point")
func initSwiftExtension() {
    SwiftGodot.initialize(types: [Passkey.self])
}

@Godot
class Passkey: RefCounted, PasskeyDelegate {
    private let nativePasskey = NativePasskey()

    // Define signals for Godot to listen to
    #signal("sign_in_completed", arguments: ["responseJson": String.self])
    #signal("sign_in_error", arguments: ["errorMessage": String.self])
    #signal("create_passkey_completed", arguments: ["responseJson": String.self])
    #signal("create_passkey_error", arguments: ["errorMessage": String.self])

    required init() {
        super.init()
        nativePasskey.delegate = self
    }

    required init(nativeHandle: UnsafeRawPointer) {
        super.init(nativeHandle: nativeHandle)
        nativePasskey.delegate = self
    }

    @Callable
    func initiateSignInWithPasskey(requestJson: String) {
        nativePasskey.initiateSignInWithPasskey(requestJson: requestJson)
    }

    @Callable
    func createPasskey(requestJson: String) {
        nativePasskey.createPasskey(requestJson: requestJson)
    }

    // MARK: - PasskeyDelegate
    func didCompleteWithSuccess(_ responseJson: String) {
        emit(signal: Passkey.sign_in_completed, responseJson)
    }

    func didEncounterError(_ errorMessage: String) {
        emit(signal: Passkey.sign_in_error, errorMessage)
    }
}

