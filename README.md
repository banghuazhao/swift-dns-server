# Swift DNS Server

A DNS server implementation in Swift, built as part of the [Build Your Own X](https://github.com/codecrafters-io/build-your-own-x) challenge.

## Status

🚧 **Work in Progress** 🚧

This project is currently under development. The implementation follows the DNS protocol specification (RFC 1035) and is being built incrementally.

## Current Implementation

### ✅ Completed
- **UDP Server**: Basic UDP server implementation using Network framework
- **DNS Header Section**: Complete parsing and serialization of DNS message headers
  - Packet ID handling (echo incoming ID in responses)
  - All header flags (QR, OPCODE, AA, TC, RD, RA, Z, RCODE)
  - Section counts (QDCOUNT, ANCOUNT, NSCOUNT, ARCOUNT)
  - Big-endian encoding support

### 🔄 In Progress
- DNS Question section parsing and handling
- DNS Answer section implementation
- DNS Authority and Additional sections

## Testing

The server responds to DNS queries on port 2053. Test with:

```bash
# Using dig
dig @127.0.0.1 -p 2053 +noedns codecrafters.io

# Using hex packet
echo -n '04d2010000010000000000000c636f6465637261667465727302696f0000010001' | xxd -r -p | nc -u -w 1 127.0.0.1 2053 | hexdump -C
```

## Building

```bash
xcodebuild -scheme SwiftDNSServer -configuration Debug build
```

## Running

```bash
# Build and run
xcodebuild -scheme SwiftDNSServer -configuration Debug build
./build/Debug/SwiftDNSServer
```

## Project Structure

- `SwiftDNSServer/main.swift` - Application entry point
- `SwiftDNSServer/UDPServer.swift` - UDP server implementation
- `SwiftDNSServer/DNSHeader.swift` - DNS header parsing and serialization

## License

Copyright Apps Bay Limited. All rights reserved.
