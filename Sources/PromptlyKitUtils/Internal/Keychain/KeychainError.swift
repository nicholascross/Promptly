import Foundation

enum KeychainError: Error {
    case success
    case unimplemented
    case diskFull
    case ioError
    case invalidParameter
    case writePermissionError
    case allocateFailure
    case userCanceled
    case badRequest
    case internalComponent
    case coreFoundationUnknown
    case notAvailable
    case readOnly
    case authFailed
    case noSuchKeychain
    case invalidKeychain
    case duplicateKeychain
    case duplicateCallback
    case invalidCallback
    case duplicateItem
    case itemNotFound
    case bufferTooSmall
    case dataTooLarge
    case noSuchAttr
    case invalidItemRef
    case invalidSearchRef
    case noSuchClass
    case noDefaultKeychain
    case interactionNotAllowed
    case readOnlyAttr
    case wrongSecVersion
    case keySizeNotAllowed
    case noStorageModule
    case noCertificateModule
    case noPolicyModule
    case interactionRequired
    case dataNotAvailable
    case dataNotModifiable
    case createChainFailed
    case aclNotSimple
    case policyNotFound
    case invalidTrustSetting
    case noAccessForItem
    case invalidOwnerEdit
    case trustNotAvailable
    case unsupportedFormat
    case unknownFormat
    case keyIsSensitive
    case multiplePrivKeys
    case passphraseRequired
    case invalidPasswordRef
    case invalidTrustSettings
    case noTrustSettings
    case pkcs12VerifyFailure
    case decodeError
    case unknownError(OSStatus)

    // swiftlint:disable cyclomatic_complexity
    // swiftlint:disable:next function_body_length
    init(status: OSStatus) {
        switch status {
        case errSecSuccess: self = .success
        case errSecUnimplemented: self = .unimplemented
        case errSecDiskFull: self = .diskFull
        case errSecIO: self = .ioError
        case errSecParam: self = .invalidParameter
        case errSecWrPerm: self = .writePermissionError
        case errSecAllocate: self = .allocateFailure
        case errSecUserCanceled: self = .userCanceled
        case errSecBadReq: self = .badRequest
        case errSecInternalComponent: self = .internalComponent
        case errSecCoreFoundationUnknown: self = .coreFoundationUnknown
        case errSecNotAvailable: self = .notAvailable
        case errSecReadOnly: self = .readOnly
        case errSecAuthFailed: self = .authFailed
        case errSecNoSuchKeychain: self = .noSuchKeychain
        case errSecInvalidKeychain: self = .invalidKeychain
        case errSecDuplicateKeychain: self = .duplicateKeychain
        case errSecDuplicateCallback: self = .duplicateCallback
        case errSecInvalidCallback: self = .invalidCallback
        case errSecDuplicateItem: self = .duplicateItem
        case errSecItemNotFound: self = .itemNotFound
        case errSecBufferTooSmall: self = .bufferTooSmall
        case errSecDataTooLarge: self = .dataTooLarge
        case errSecNoSuchAttr: self = .noSuchAttr
        case errSecInvalidItemRef: self = .invalidItemRef
        case errSecInvalidSearchRef: self = .invalidSearchRef
        case errSecNoSuchClass: self = .noSuchClass
        case errSecNoDefaultKeychain: self = .noDefaultKeychain
        case errSecInteractionNotAllowed: self = .interactionNotAllowed
        case errSecReadOnlyAttr: self = .readOnlyAttr
        case errSecWrongSecVersion: self = .wrongSecVersion
        case errSecKeySizeNotAllowed: self = .keySizeNotAllowed
        case errSecNoStorageModule: self = .noStorageModule
        case errSecNoCertificateModule: self = .noCertificateModule
        case errSecNoPolicyModule: self = .noPolicyModule
        case errSecInteractionRequired: self = .interactionRequired
        case errSecDataNotAvailable: self = .dataNotAvailable
        case errSecDataNotModifiable: self = .dataNotModifiable
        case errSecCreateChainFailed: self = .createChainFailed
        case errSecACLNotSimple: self = .aclNotSimple
        case errSecPolicyNotFound: self = .policyNotFound
        case errSecInvalidTrustSetting: self = .invalidTrustSetting
        case errSecNoAccessForItem: self = .noAccessForItem
        case errSecInvalidOwnerEdit: self = .invalidOwnerEdit
        case errSecTrustNotAvailable: self = .trustNotAvailable
        case errSecUnsupportedFormat: self = .unsupportedFormat
        case errSecUnknownFormat: self = .unknownFormat
        case errSecKeyIsSensitive: self = .keyIsSensitive
        case errSecMultiplePrivKeys: self = .multiplePrivKeys
        case errSecPassphraseRequired: self = .passphraseRequired
        case errSecInvalidPasswordRef: self = .invalidPasswordRef
        case errSecInvalidTrustSettings: self = .invalidTrustSettings
        case errSecNoTrustSettings: self = .noTrustSettings
        case errSecPkcs12VerifyFailure: self = .pkcs12VerifyFailure
        case errSecDecode: self = .decodeError
        default: self = .unknownError(status)
        }
    }
}

// swiftlint:enable cyclomatic_complexity
