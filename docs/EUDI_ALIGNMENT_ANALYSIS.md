# EU Digital Identity Wallet Library Alignment Analysis

## Overview

This document analyzes the differences between our current DJ_Medi_Wallet_25 implementation and the EU Digital Identity Wallet reference libraries, and outlines the changes needed to align with their security and initialization patterns.

## Key Differences Identified

### 1. Initialization Pattern

**EUDI Libraries:**
- Use Builder pattern for flexible configuration
- Support multiple configuration objects (OpenId4VCI, OpenId4VP, etc.)
- Allow custom storage and secure area implementations
- Register services dynamically (OpenId4VCIService, OpenId4VPManager)
- Support dependency injection for networking, logging, and storage

**Our Implementation:**
- Simple singleton pattern
- Hard-coded initialization
- No configuration flexibility
- Direct instantiation of dependencies

### 2. Secure Key Storage

**EUDI iOS (eudi-lib-ios-wallet-kit):**
```swift
// Uses SecureArea abstraction
let kcSks = KeyChainSecureKeyStorage(serviceName: self.serviceName, accessGroup: accessGroup)
if SecureEnclave.isAvailable { 
    SecureAreaRegistry.shared.register(secureArea: SecureEnclaveSecureArea.create(storage: kcSks)) 
}
SecureAreaRegistry.shared.register(secureArea: SoftwareSecureArea.create(storage: kcSks))
```

**Our iOS Implementation:**
```swift
// Direct CryptoKit usage
let privateKey = P256.Signing.PrivateKey()
try self.storePrivateKey(privateKey)
```

**Key Differences:**
- EUDI uses SecureArea abstraction for flexibility
- EUDI registers both Secure Enclave and software fallback
- EUDI allows multiple secure area implementations
- Our implementation is simpler but less flexible

### 3. Authentication Requirements

**EUDI Libraries:**
- User authentication is configurable
- Can be required per operation (issue, present)
- Integrated with biometric prompts
- Has DEBUG mode that disables auth

**Our Implementation:**
- Authentication is called separately
- Not integrated with key operations
- No per-operation configuration

### 4. Storage Architecture

**EUDI Android:**
```kotlin
// Storage abstraction
interface Storage {
    fun read(key: String): ByteArray?
    fun write(key: String, value: ByteArray)
    fun delete(key: String)
}

// Multiple implementations
val storage = AndroidStorage(context)
```

**Our Android Implementation:**
```kotlin
// Direct file-based implementation
class SecureStorage(private val context: Context) {
    private fun getStorageDirectory(): File {
        return File(context.filesDir, STORAGE_DIR)
    }
}
```

### 5. Service Name Configuration

**EUDI iOS:**
```swift
public init(serviceName: String? = nil, ...) {
    self.serviceName = serviceName ?? Self.defaultServiceName
    // Validates no ":" in service name
    try Self.validateServiceParams(serviceName: serviceName)
}
```

**Our iOS Implementation:**
```swift
private init() {
    self.securityManager = SecurityManager()
    // Uses hard-coded "com.djmediwallet.keychain"
}
```

### 6. Access Group Support (iOS)

**EUDI iOS:**
- Supports keychain access groups for app groups
- Allows sharing credentials between apps
- Configurable per wallet instance

**Our iOS Implementation:**
- No access group support
- Keys isolated to single app

### 7. User Authentication Integration

**EUDI iOS:**
```swift
public var userAuthenticationRequired: Bool
// Used during key operations:
if userAuthenticationRequired {
    // Prompt for biometric/passcode
}
```

**EUDI Android:**
```kotlin
val parameterSpec = KeyGenParameterSpec.Builder(...)
    .setUserAuthenticationRequired(config.userAuthenticationRequired)
    .setUserAuthenticationValidityDurationSeconds(30)
```

**Our Implementations:**
- Have authentication methods
- But not integrated with key access
- No timeout configuration

## Recommended Changes

### High Priority (Security Critical)

1. **Add Configuration Objects**
   - Create `WalletConfig` for initialization parameters
   - Support service name configuration
   - Add user authentication requirements flag

2. **Integrate User Authentication with Key Operations**
   - iOS: Add authentication context to key retrieval
   - Android: Set `setUserAuthenticationRequired(true)` in KeyGenParameterSpec
   - Add timeout configuration

3. **Add Secure Enclave Support (iOS)**
   - Check SecureEnclave availability
   - Use Secure Enclave when available
   - Fallback to software keys

4. **Add Access Group Support (iOS)**
   - Allow keychain access group configuration
   - Enable credential sharing if needed

### Medium Priority (Architecture)

5. **Implement Builder Pattern**
   - Add `WalletBuilder` class
   - Support custom storage implementations
   - Allow dependency injection

6. **Add Storage Abstraction**
   - Define storage interface/protocol
   - Support multiple backends
   - Enable custom implementations

7. **Add Service Registry Pattern**
   - Create registry for OpenID4VCI/VP services
   - Support dynamic service registration
   - Enable multiple issuer configurations

### Low Priority (Enhancement)

8. **Add Logging Infrastructure**
   - Support custom logger injection
   - Add transaction logging
   - File-based logging option

9. **Add Networking Abstraction**
   - Support custom HTTP clients
   - Enable testing with mock clients
   - Add retry and timeout configuration

10. **Add Document Status Resolution**
    - Support credential status checking
    - Integration with revocation lists
    - Status update mechanisms

## Security Improvements to Implement

### iOS Specific

1. **Secure Enclave Integration**
```swift
if SecureEnclave.isAvailable {
    // Use Secure Enclave for key generation
    let privateKey = try SecureEnclave.P256.Signing.PrivateKey()
} else {
    // Fallback to CryptoKit
    let privateKey = P256.Signing.PrivateKey()
}
```

2. **Biometric-Protected Key Access**
```swift
let access = SecAccessControlCreateWithFlags(
    nil,
    kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
    [.biometryCurrentSet, .privateKeyUsage],
    nil
)
```

3. **LAContext Integration**
```swift
let context = LAContext()
context.localizedReason = "Authenticate to access credentials"
// Pass context to keychain operations
```

### Android Specific

1. **User Authentication Timeout**
```kotlin
val parameterSpec = KeyGenParameterSpec.Builder(...)
    .setUserAuthenticationRequired(true)
    .setUserAuthenticationValidityDurationSeconds(30)
    .build()
```

2. **StrongBox Support**
```kotlin
if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
    builder.setIsStrongBoxBacked(true)
}
```

3. **Biometric Prompt Integration**
```kotlin
val biometricPrompt = BiometricPrompt(
    activity,
    executor,
    object : BiometricPrompt.AuthenticationCallback() {
        override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
            // Access key after authentication
        }
    }
)
```

## Implementation Priority

### Phase 1: Critical Security Updates
1. Add user authentication requirement to key generation
2. Implement Secure Enclave support (iOS)
3. Add authentication timeout (Android)
4. Integrate biometric prompts with key access

### Phase 2: Configuration & Flexibility
1. Add WalletConfig class
2. Implement Builder pattern
3. Support service name configuration
4. Add access group support (iOS)

### Phase 3: Architecture Alignment
1. Add storage abstraction
2. Implement service registry
3. Add logging infrastructure
4. Support custom implementations

## Conclusion

While our current implementation provides basic security features, aligning with the EUDI wallet libraries will:
- Improve security posture with Secure Enclave and StrongBox
- Enable better user authentication integration
- Provide configuration flexibility
- Support future extensibility
- Align with EU standards and best practices

The most critical changes are integrating user authentication with key operations and using hardware-backed secure storage when available.
