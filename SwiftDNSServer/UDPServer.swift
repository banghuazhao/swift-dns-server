//
// Created by Banghua Zhao on 17/08/2025
// Copyright Apps Bay Limited. All rights reserved.
//

import Foundation
import Network

// MARK: - UDP Server Protocol

protocol UDPServerProtocol {
    func start() throws
    func stop()
    var isRunning: Bool { get }
}

// MARK: - UDP Server Implementation

final class UDPServer: UDPServerProtocol {
    // MARK: - Properties

    private let port: UInt16
    private var listener: NWListener?
    private let queue: DispatchQueue
    private var activeConnections: [NWConnection] = []

    var isRunning: Bool {
        return listener?.state == .ready
    }

    // MARK: - Initialization

    init(port: UInt16,
         queue: DispatchQueue = DispatchQueue(label: "udp.server.queue", qos: .userInitiated)
    ) {
        self.port = port
        self.queue = queue
    }

    // MARK: - Public Methods

    func start() throws {
        guard listener == nil else {
            throw UDPServerError.alreadyRunning
        }

        do {
            try createListener()
            setupStateHandler()
            setupConnectionHandler()
            startListening()
        } catch {
            throw UDPServerError.failedToStart(error)
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil

        activeConnections.removeAll()

        print("UDP Server stopped")
    }

    // MARK: - Private Methods

    private func createListener() throws {
        let port = NWEndpoint.Port(integerLiteral: self.port)
        listener = try NWListener(using: .udp, on: port)
    }

    private func setupStateHandler() {
        listener?.stateUpdateHandler = { [weak self] state in
            self?.handleStateChange(state)
        }
    }

    private func setupConnectionHandler() {
        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleNewConnection(connection)
        }
    }

    private func startListening() {
        listener?.start(queue: queue)
    }

    private func handleStateChange(_ state: NWListener.State) {
        switch state {
        case .ready:
            print("✅ UDP Server is ready and listening on port \(port)")
        case let .failed(error):
            print("❌ UDP Server failed with error: \(error)")
        case .cancelled:
            print("🛑 UDP Server cancelled")
        case let .waiting(error):
            print("⏳ UDP Server waiting: \(error)")
        case .setup:
            print("🖥️ UDP Server setting up...")
        @unknown default:
            print("❓ UDP Server unknown state")
        }
    }

    private func handleNewConnection(_ connection: NWConnection) {
        print("New UDP connection from: \(connection.endpoint)")

        // Hold the connection (no need for sync since we're already on the queue)
        activeConnections.append(connection)

        // Set up connection state handler
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("✅ Connection ready: \(connection.endpoint)")
            case let .failed(error):
                print("❌ Connection failed: \(error)")
                self?.removeConnection(connection)
            case .cancelled:
                print("🛑 Connection cancelled: \(connection.endpoint)")
                self?.removeConnection(connection)
            default:
                break
            }
        }

        // Start the connection
        connection.start(queue: queue)

        // Set up receive handler
        setupConnectionReceiveHandler(connection)
    }

    private func setupConnectionReceiveHandler(_ connection: NWConnection) {
        connection.receiveMessage { [weak self] data, _, _, error in
            if let error = error {
                print("❌ Receive error: \(error)")
                self?.removeConnection(connection)
                return
            }

            if let data = data {
                self?.handleReceivedData(data, from: connection)
            }

            // Continue receiving for this connection
            self?.setupConnectionReceiveHandler(connection)
        }
    }

    private func handleReceivedData(_ data: Data, from connection: NWConnection) {
        // For this stage, respond with a 12-byte DNS header with fixed, expected values
        // ID: 1234, QR: 1, OPCODE: 0, AA: 0, TC: 0, RD: 0, RA: 0, Z: 0, RCODE: 0
        // QDCOUNT/ANCOUNT/NSCOUNT/ARCOUNT: 0
        do {
            // Echo the incoming packet's ID to satisfy clients like dig
            let incomingId = (try? data.readUInt16BE(at: 0)) ?? 0
            let header = DNSHeader(
                id: incomingId,
                isResponse: true,
                opcode: .query,
                isAuthoritativeAnswer: false,
                isTruncated: false,
                recursionDesired: false,
                recursionAvailable: false,
                z: 0,
                responseCode: .noError,
                questionCount: 0,
                answerRecordCount: 0,
                authorityRecordCount: 0,
                additionalRecordCount: 0
            )

            let responseData = try header.serialize()

            connection.send(content: responseData, completion: .contentProcessed { error in
                if let error = error {
                    print("❌ Send error: \(error)")
                } else {
                    print("✅ DNS header response sent to \(connection.endpoint)")
                }
            })
        } catch {
            print("❌ Failed to serialize DNS header: \(error)")
        }
    }

    private func removeConnection(_ connection: NWConnection) {
        if let index = activeConnections.firstIndex(where: { $0 === connection }) {
            activeConnections.remove(at: index)
            print("🗑️ Removed connection: \(connection.endpoint)")
        }
    }
}

// MARK: - UDP Server Errors

enum UDPServerError: LocalizedError {
    case alreadyRunning
    case failedToStart(Error)

    var errorDescription: String? {
        switch self {
        case .alreadyRunning:
            return "UDP Server is already running"
        case let .failedToStart(error):
            return "Failed to start UDP Server: \(error.localizedDescription)"
        }
    }
}
