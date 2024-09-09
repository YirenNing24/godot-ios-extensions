import Network
import SwiftGodot

let OK: Int = 0

@Godot
class LocalNetworkDiscovery: RefCounted {
	#signal("device_discovered", arguments: ["name": String.self, "port": Int.self, "hash_value": Int.self])
	#signal("device_lost", arguments: ["name": String.self, "hash_value": Int.self])
	#signal(
		"device_updated",
		arguments: ["name": String.self, "port": Int.self, "old_hash_value": Int.self, "new_hash_value": Int.self]
	)

	enum NetworkDiscoveryError: Int, Error {
		case failedToResolveEndpoint = 1
		case incompatibleIPV6Address = 2
	}

	var browser: NWBrowser? = nil
	var connection: NWConnection? = nil
	var discoveredDevices: [Int: (NWBrowser.Result)] = [:]

	deinit {
		stop()
	}

	@Callable
	func start(typeDescriptor: String) {
		GD.print("Starting LocalNetworkDiscovery for \(typeDescriptor)...")
		let descriptor: NWBrowser.Descriptor = NWBrowser.Descriptor.bonjourWithTXTRecord(
			type: typeDescriptor,
			domain: "local."
		)
		let browser: NWBrowser = NWBrowser(for: descriptor, using: .tcp)

		browser.stateUpdateHandler = stateChanged(to:)
		browser.browseResultsChangedHandler = resultsChanged

		browser.start(queue: DispatchQueue.global(qos: .userInitiated))
		self.browser = browser
	}

	@Callable
	func stop() {
		if browser == nil {
			return
		}

		browser?.stateUpdateHandler = nil
		browser?.browseResultsChangedHandler = nil
		browser?.cancel()
		browser = nil
		GD.print("LocalNetworkDiscovery stopped")
	}

	@Callable
	func resolveEndpoint(hashValue: Int, onComplete: Callable) {
		// This whole thing is unfortunately necessary since you can't resolve an endpoint to host:port
		if let result: NWBrowser.Result = discoveredDevices[hashValue] {
			let endpoint: NWEndpoint = result.endpoint
			var port: Int = 0
			switch result.metadata {
			case .bonjour(let record):
				port = Int(record.dictionary["port"] ?? "0") ?? 0
			default:
				break
			}

			let networkParams: NWParameters = NWParameters.tcp
			networkParams.prohibitedInterfaceTypes = [.loopback]
			networkParams.serviceClass = NWParameters.ServiceClass.responsiveData

			let ip: NWProtocolIP.Options = networkParams.defaultProtocolStack.internetProtocol! as! NWProtocolIP.Options
			ip.version = .v4

			connection = NWConnection(to: endpoint, using: networkParams)
			connection?.stateUpdateHandler = { state in
				switch state {
				case .ready:
					if let innerEndpoint: NWEndpoint = self.connection?.currentPath?.remoteEndpoint,
						case .hostPort(let host, let tempPort) = innerEndpoint
					{
						self.connection?.cancel()

						var address_string: String = ""
						switch host {
						case .ipv4(let address):
							address_string = self.ipAddressToString(address)
							break
						case .ipv6(let address):
							if let ipv4Address = address.asIPv4 {
								address_string = self.ipAddressToString(ipv4Address)
							} else {
								GD.pushError("Failed to resolve endpoint: Got incompatible IPv6 address")
								onComplete.callDeferred(
									Variant(NetworkDiscoveryError.incompatibleIPV6Address.rawValue),
									Variant(),
									Variant()
								)
								return
							}
						default:
							break
						}

						onComplete.callDeferred(Variant(OK), Variant(address_string), Variant(port))
					}
				default:
					break
				}
			}
			connection?.start(queue: DispatchQueue.global(qos: .userInteractive))
		} else {
			GD.pushError("Found no endpoint corresponding to the hashValue \(hashValue)")
			onComplete.callDeferred(
				Variant(NetworkDiscoveryError.failedToResolveEndpoint.rawValue),
				Variant(),
				Variant()
			)
		}
	}

	func stateChanged(to newState: NWBrowser.State) {
		switch newState {
		case .failed(let error):
			GD.pushError("LocalNetworkDiscovery failed: \(error.localizedDescription)")
		default:
			break
		}
	}

	func resultsChanged(updated: Set<NWBrowser.Result>, changes: Set<NWBrowser.Result.Change>) {
		for change: NWBrowser.Result.Change in changes {
			switch change
			{
			case .added(let result):
				GD.print(
					"LocalNetworkDiscovery discovered server: \(result.endpoint.debugDescription), Meta: \(result.metadata) (\(result.hashValue))"
				)
				var server_port: Int = 0

				switch result.metadata
				{
				case .bonjour(let record):
					server_port = Int(record.dictionary["port"] ?? "0") ?? 0
				default:
					break
				}

				switch result.endpoint
				{
				case .service(let service):
					emit(signal: LocalNetworkDiscovery.deviceDiscovered, service.name, server_port, result.hashValue)
				default:
					break
				}

				discoveredDevices[result.hashValue] = result

			case .removed(let result):
				GD.print(
					"LocalNetworkDiscovery lost server \(result.endpoint.debugDescription), Meta: \(result.metadata) (\(result.hashValue))"
				)
				discoveredDevices.removeValue(forKey: result.hashValue)

				switch result.endpoint
				{
				case .service(let service):
					emit(signal: LocalNetworkDiscovery.deviceLost, service.name, result.hashValue)
				default:
					break
				}

			case .changed(let old, let new, flags: _):
				GD.print("LocalNetworkDiscovery server changed \(old.endpoint) -> \(new.endpoint)")
				var server_port: Int = 0
				switch new.metadata
				{
				case .bonjour(let record):
					server_port = Int(record.dictionary["port"] ?? "0") ?? 0
				default:
					break
				}

				switch new.endpoint
				{
				case .service(let service):
					emit(
						signal: LocalNetworkDiscovery.deviceUpdated,
						service.name,
						server_port,
						old.hashValue,
						new.hashValue
					)
				default:
					break
				}

				discoveredDevices.removeValue(forKey: old.hashValue)
				discoveredDevices[new.hashValue] = new
			case .identical:
				break
			}
		}
	}

	// Helpers

	func ipAddressToString(_ address: IPv4Address) -> String {
		return String("\(address.rawValue[0]).\(address.rawValue[1]).\(address.rawValue[2]).\(address.rawValue[3])")
	}
}
