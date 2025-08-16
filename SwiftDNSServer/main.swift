//
// Created by Banghua Zhao on 17/08/2025
// Copyright Apps Bay Limited. All rights reserved.
//

import Foundation

print("🚀 Starting UDP Server on port 2053...")

let server = UDPServer(port: 2053)

// Handle graceful shutdown
signal(SIGINT) { _ in
    print("\n🛑 Shutting down UDP Server...")
    server.stop()
    exit(0)
}

do {
    try server.start()

    // Keep the server running
    RunLoop.main.run()
} catch {
    print("❌ Failed to start server: \(error)")
    exit(1)
}
