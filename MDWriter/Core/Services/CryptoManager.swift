//
//  CryptoManager.swift
//  MDWriter
//
//  AES-256-GCM Encryption and Decryption Manager with PBKDF2 Key Derivation
//

import CommonCrypto
import CryptoKit
import Foundation
import Security

public enum CryptoError: Error, LocalizedError {
    case invalidHeader
    case keyDerivationFailed
    case encryptionFailed
    case decryptionFailed
    case missingPassword

    public var errorDescription: String? {
        switch self {
        case .invalidHeader:
            return String(localized: "Invalid backup format or corrupted file header.", comment: "Crypto error")
        case .keyDerivationFailed:
            return String(localized: "Key derivation failed.", comment: "Crypto error")
        case .encryptionFailed:
            return String(localized: "Encryption failed.", comment: "Crypto error")
        case .decryptionFailed:
            return String(localized: "Decryption failed. Please check if the password is correct.", comment: "Crypto error")
        case .missingPassword:
            return String(localized: "Encryption password is required.", comment: "Crypto error")
        }
    }
}

public struct CryptoManager: Sendable {
    public static let shared = CryptoManager()

    private static let magicHeader = "MDWBK1ENC".data(using: .utf8)! // 9 bytes
    private static let saltLength = 16
    private static let pbkdf2Rounds: UInt32 = 20_000

    public init() {}

    // MARK: - Encryption

    public func encrypt(data: Data, password: String) throws -> Data {
        guard !password.isEmpty else {
            throw CryptoError.missingPassword
        }

        // 1. Generate random salt (16 bytes)
        var salt = Data(count: CryptoManager.saltLength)
        let saltResult = salt.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, CryptoManager.saltLength, $0.baseAddress!)
        }
        guard saltResult == errSecSuccess else {
            throw CryptoError.encryptionFailed
        }

        // 2. Derive 256-bit key via PBKDF2
        let keyData = try deriveKey(password: password, salt: salt)
        let symmetricKey = SymmetricKey(data: keyData)

        // 3. Encrypt data with AES-GCM
        let sealedBox = try AES.GCM.seal(data, using: symmetricKey)
        guard let combined = sealedBox.combined else {
            throw CryptoError.encryptionFailed
        }

        // 4. Construct payload: MAGIC (9 bytes) + SALT (16 bytes) + COMBINED (Nonce + Ciphertext + Tag)
        var resultData = Data()
        resultData.append(CryptoManager.magicHeader)
        resultData.append(salt)
        resultData.append(combined)
        return resultData
    }

    // MARK: - Decryption

    public func decrypt(data: Data, password: String) throws -> Data {
        guard !password.isEmpty else {
            throw CryptoError.missingPassword
        }

        let magicLength = CryptoManager.magicHeader.count
        let minLength = magicLength + CryptoManager.saltLength + 28 // 12 nonce + 16 tag minimum
        guard data.count >= minLength else {
            throw CryptoError.invalidHeader
        }

        let header = data.subdata(in: 0..<magicLength)
        guard header == CryptoManager.magicHeader else {
            throw CryptoError.invalidHeader
        }

        let salt = data.subdata(in: magicLength..<(magicLength + CryptoManager.saltLength))
        let combinedData = data.subdata(in: (magicLength + CryptoManager.saltLength)..<data.count)

        let keyData = try deriveKey(password: password, salt: salt)
        let symmetricKey = SymmetricKey(data: keyData)

        let sealedBox = try AES.GCM.SealedBox(combined: combinedData)
        do {
            return try AES.GCM.open(sealedBox, using: symmetricKey)
        } catch {
            throw CryptoError.decryptionFailed
        }
    }

    public func isEncrypted(data: Data) -> Bool {
        let magicLength = CryptoManager.magicHeader.count
        guard data.count >= magicLength else { return false }
        return data.subdata(in: 0..<magicLength) == CryptoManager.magicHeader
    }

    // MARK: - PBKDF2 Key Derivation

    private func deriveKey(password: String, salt: Data) throws -> Data {
        let passwordData = password.data(using: .utf8)!
        var derivedKey = Data(count: 32) // 256 bits

        let result = derivedKey.withUnsafeMutableBytes { derivedKeyBytes in
            salt.withUnsafeBytes { saltBytes in
                passwordData.withUnsafeBytes { passwordBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.baseAddress?.assumingMemoryBound(to: Int8.self),
                        passwordData.count,
                        saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        CryptoManager.pbkdf2Rounds,
                        derivedKeyBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        32
                    )
                }
            }
        }

        guard result == kCCSuccess else {
            throw CryptoError.keyDerivationFailed
        }

        return derivedKey
    }

    // MARK: - Keychain Helper

    private let keychainService = "com.steveshi.MDWriter.encryption"
    private let keychainAccount = "masterKey"

    public func saveMasterPassword(_ password: String) -> Bool {
        guard let data = password.data(using: .utf8) else { return false }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]

        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = data

        let status = SecItemAdd(attributes as CFDictionary, nil)
        return status == errSecSuccess
    }

    public func getMasterPassword() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    public func deleteMasterPassword() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        SecItemDelete(query as CFDictionary)
    }
}
