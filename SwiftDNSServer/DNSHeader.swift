//
// Created by Banghua Zhao on 18/08/2025
// DNS Header model, parser, and serializer
//

import Foundation

// MARK: - DNS Opcode

public enum DNSOpcode: UInt8 {
    case query = 0
    case iquery = 1
    case status = 2
    // 3 is reserved
    case notify = 4
    case update = 5

    case unknown = 255
}

// MARK: - DNS Response Code (RCODE)

public enum DNSResponseCode: UInt8, Error {
    case noError = 0
    case formatError = 1
    case serverFailure = 2
    case nameError = 3
    case notImplemented = 4
    case refused = 5

    // Extended and unknown codes
    case unknown = 255
}

// MARK: - DNS Header Errors

public enum DNSHeaderError: LocalizedError {
    case insufficientBytes(expected: Int, actual: Int)
    case invalidZReservedBits(UInt8)

    public var errorDescription: String? {
        switch self {
        case let .insufficientBytes(expected, actual):
            return "DNS header requires at least \(expected) bytes, got \(actual)"
        case let .invalidZReservedBits(bits):
            return "DNS header reserved Z bits must be 0, got \(bits)"
        }
    }
}

// MARK: - DNS Header Model

public struct DNSHeader {
    public var id: UInt16

    // Flags and codes
    public var isResponse: Bool // QR (bit 15)
    public var opcode: DNSOpcode // bits 14..11
    public var isAuthoritativeAnswer: Bool // AA (bit 10)
    public var isTruncated: Bool // TC (bit 9)
    public var recursionDesired: Bool // RD (bit 8)
    public var recursionAvailable: Bool // RA (bit 7)
    public var z: UInt8 // bits 6..4, must be 0 for RFC 1035
    public var responseCode: DNSResponseCode // bits 3..0

    // Section counts
    public var questionCount: UInt16 // QDCOUNT
    public var answerRecordCount: UInt16 // ANCOUNT
    public var authorityRecordCount: UInt16 // NSCOUNT
    public var additionalRecordCount: UInt16 // ARCOUNT

    public init(
        id: UInt16,
        isResponse: Bool,
        opcode: DNSOpcode,
        isAuthoritativeAnswer: Bool,
        isTruncated: Bool,
        recursionDesired: Bool,
        recursionAvailable: Bool,
        z: UInt8 = 0,
        responseCode: DNSResponseCode,
        questionCount: UInt16,
        answerRecordCount: UInt16,
        authorityRecordCount: UInt16,
        additionalRecordCount: UInt16
    ) {
        self.id = id
        self.isResponse = isResponse
        self.opcode = opcode
        self.isAuthoritativeAnswer = isAuthoritativeAnswer
        self.isTruncated = isTruncated
        self.recursionDesired = recursionDesired
        self.recursionAvailable = recursionAvailable
        self.z = z & 0b111
        self.responseCode = responseCode
        self.questionCount = questionCount
        self.answerRecordCount = answerRecordCount
        self.authorityRecordCount = authorityRecordCount
        self.additionalRecordCount = additionalRecordCount
    }
}

// MARK: - Parsing & Serialization

public extension DNSHeader {
    static let byteLength = 12

    static func parse(from data: Data) throws -> (header: DNSHeader, remainder: Data) {
        guard data.count >= DNSHeader.byteLength else {
            throw DNSHeaderError.insufficientBytes(expected: DNSHeader.byteLength, actual: data.count)
        }

        let id = try data.readUInt16BE(at: 0)
        let flags = try data.readUInt16BE(at: 2)
        let qdCount = try data.readUInt16BE(at: 4)
        let anCount = try data.readUInt16BE(at: 6)
        let nsCount = try data.readUInt16BE(at: 8)
        let arCount = try data.readUInt16BE(at: 10)

        let isResponse = ((flags >> 15) & 0b1) == 1

        let opcodeRaw = UInt8((flags >> 11) & 0b1111)
        let opcode = DNSOpcode(rawValue: opcodeRaw) ?? .unknown

        let isAuthoritativeAnswer = ((flags >> 10) & 0b1) == 1
        let isTruncated = ((flags >> 9) & 0b1) == 1
        let recursionDesired = ((flags >> 8) & 0b1) == 1
        let recursionAvailable = ((flags >> 7) & 0b1) == 1

        let zBits = UInt8((flags >> 4) & 0b111)
        let rcodeRaw = UInt8(flags & 0b1111)
        let responseCode = DNSResponseCode(rawValue: rcodeRaw) ?? .unknown

        let header = DNSHeader(
            id: id,
            isResponse: isResponse,
            opcode: opcode,
            isAuthoritativeAnswer: isAuthoritativeAnswer,
            isTruncated: isTruncated,
            recursionDesired: recursionDesired,
            recursionAvailable: recursionAvailable,
            z: zBits,
            responseCode: responseCode,
            questionCount: qdCount,
            answerRecordCount: anCount,
            authorityRecordCount: nsCount,
            additionalRecordCount: arCount
        )

        let remainder = data.advanced(by: DNSHeader.byteLength)
        return (header, remainder)
    }

    func serialize() throws -> Data {
        guard z == 0 else {
            throw DNSHeaderError.invalidZReservedBits(z)
        }

        var flags: UInt16 = 0
        flags |= (isResponse ? 1 : 0) << 15
        flags |= UInt16((opcode == .unknown ? 0 : opcode.rawValue) & 0b1111) << 11
        flags |= (isAuthoritativeAnswer ? 1 : 0) << 10
        flags |= (isTruncated ? 1 : 0) << 9
        flags |= (recursionDesired ? 1 : 0) << 8
        flags |= (recursionAvailable ? 1 : 0) << 7
        flags |= UInt16(z & 0b111) << 4
        flags |= UInt16((responseCode == .unknown ? 0 : responseCode.rawValue) & 0b1111)

        var data = Data(capacity: DNSHeader.byteLength)
        data.appendUInt16BE(id)
        data.appendUInt16BE(flags)
        data.appendUInt16BE(questionCount)
        data.appendUInt16BE(answerRecordCount)
        data.appendUInt16BE(authorityRecordCount)
        data.appendUInt16BE(additionalRecordCount)
        return data
    }
}

// MARK: - Data helpers (Big-Endian)

public extension Data {
    func readUInt16BE(at offset: Int) throws -> UInt16 {
        let end = offset + 2
        guard offset >= 0, end <= count else {
            throw DNSHeaderError.insufficientBytes(expected: end, actual: count)
        }
        return withUnsafeBytes { rawBuffer in
            let base = rawBuffer.bindMemory(to: UInt8.self).baseAddress!
            let value = UInt16(base[offset]) << 8 | UInt16(base[offset + 1])
            return value
        }
    }

    mutating func appendUInt16BE(_ value: UInt16) {
        append(UInt8((value >> 8) & 0x00FF))
        append(UInt8(value & 0x00FF))
    }
}
