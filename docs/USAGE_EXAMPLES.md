# DJ_Medi_Wallet_25 Usage Examples

## Updated with EU Digital Identity Wallet Patterns

This guide shows how to use the wallet with the new configuration system aligned with the EU Digital Identity Wallet libraries.

## iOS (Swift) Usage

### Basic Initialization with Default Configuration

```swift
import DJMediWallet

// Use shared instance with default configuration
let wallet = WalletManager.shared

// Initialize wallet
wallet.initializeWallet { result in
    switch result {
    case .success:
        print("Wallet initialized successfully")
    case .failure(let error):
        print("Initialization failed: \(error)")
    }
}
```

### Custom Configuration with Builder Pattern

```swift
// Create wallet with custom configuration
do {
    let wallet = try WalletManager.Builder()
        .serviceName("com.myapp.mediwallet")
        .accessGroup("group.com.myapp")
        .userAuthenticationRequired(true)
        .authenticationTimeout(30) // 30 seconds
        .useSecureEnclave(true)
        .build()
    
    wallet.initializeWallet { result in
        // Handle result
    }
} catch {
    print("Configuration error: \(error)")
}
```

### Configuration Options Explained

```swift
let config = try WalletConfig(
    // Service name for keychain (must not contain ":")
    serviceName: "com.myapp.wallet",
    
    // Access group for sharing between apps (optional)
    accessGroup: "group.com.myapp",
    
    // Require biometric/passcode for operations
    userAuthenticationRequired: true,
    
    // Seconds before re-authentication required
    authenticationTimeout: 30,
    
    // Use Secure Enclave when available
    useSecureEnclaveWhenAvailable: true,
    
    // Trusted certificates for verifiers (optional)
    trustedReaderCertificates: [certData1, certData2]
)

let wallet = try WalletManager(config: config)
```

### Checking Secure Enclave Availability

```swift
if SecurityManager.isSecureEnclaveAvailable {
    print("Secure Enclave is available on this device")
} else {
    print("Using software-based keys")
}
```

### Debug Configuration (Development Only)

```swift
#if DEBUG
// Disable authentication for development
let wallet = try WalletManager.Builder()
    .userAuthenticationRequired(false)
    .build()
#else
let wallet = WalletManager.shared
#endif
```

### Adding Credentials

```swift
// Create a FHIR-based medical credential
let observation = Observation(
    status: "final",
    code: CodeableConcept(
        coding: [Coding(
            system: "http://loinc.org",
            code: "85354-9",
            display: "Blood pressure panel"
        )]
    ),
    effectiveDateTime: ISO8601DateFormatter().string(from: Date())
)

let credential = MedicalCredential(
    id: UUID().uuidString,
    type: "BloodPressureReading",
    issuer: "Healthcare Provider XYZ",
    issuanceDate: Date(),
    fhirResource: FHIRResource(
        resourceType: "Observation",
        id: observation.id,
        data: observation.asDictionary()
    )
)

wallet.addCredential(credential) { result in
    switch result {
    case .success(let id):
        print("Credential stored with ID: \(id)")
    case .failure(let error):
        print("Failed to store credential: \(error)")
    }
}
```

## Android (Kotlin) Usage

### Basic Initialization with Default Configuration

```kotlin
import com.djmediwallet.core.WalletManager
import com.djmediwallet.core.WalletConfig

// Get singleton instance with default configuration
val wallet = WalletManager.getInstance(context)

// Initialize wallet
lifecycleScope.launch {
    wallet.initializeWallet()
        .onSuccess { 
            Log.d("Wallet", "Initialized successfully") 
        }
        .onFailure { error -> 
            Log.e("Wallet", "Initialization failed", error) 
        }
}
```

### Custom Configuration with Builder Pattern

```kotlin
// Create wallet with custom configuration
val wallet = WalletManager.Builder(context)
    .serviceName("MyAppWalletKey")
    .userAuthenticationRequired(true)
    .authenticationTimeout(30) // 30 seconds
    .useStrongBox(true)
    .build()

lifecycleScope.launch {
    wallet.initializeWallet()
        .onSuccess { /* Handle success */ }
        .onFailure { /* Handle error */ }
}
```

### Configuration Options Explained

```kotlin
val config = WalletConfig(
    // Service name for keystore
    serviceName = "MyAppWalletKey",
    
    // Require biometric/PIN for operations
    userAuthenticationRequired = true,
    
    // Authentication timeout in seconds (-1 = every use)
    authenticationTimeoutSeconds = 30,
    
    // Use StrongBox when available (Android 9+)
    useStrongBoxWhenAvailable = true,
    
    // Trusted certificates for verifiers (optional)
    trustedReaderCertificates = listOf(cert1Bytes, cert2Bytes)
)

val wallet = WalletManager.getInstance(context, config)
```

### Using Config Builder

```kotlin
val config = WalletConfig.Builder()
    .serviceName("MyWalletKey")
    .userAuthenticationRequired(true)
    .authenticationTimeoutSeconds(30)
    .useStrongBox(true)
    .build()

val wallet = WalletManager.getInstance(context, config)
```

### Checking StrongBox Availability

```kotlin
if (SecurityManager.isStrongBoxAvailable()) {
    Log.d("Security", "StrongBox is available")
} else {
    Log.d("Security", "Using regular TEE")
}
```

### Debug Configuration (Development Only)

```kotlin
val config = if (BuildConfig.DEBUG) {
    WalletConfig.DEBUG // No authentication required
} else {
    WalletConfig.DEFAULT // Standard security
}

val wallet = WalletManager.getInstance(context, config)
```

### Adding Credentials

```kotlin
// Create a FHIR-based medical credential
val observation = Observation(
    status = "final",
    code = CodeableConcept(
        coding = listOf(
            Coding(
                system = "http://loinc.org",
                code = "85354-9",
                display = "Blood pressure panel"
            )
        )
    ),
    effectiveDateTime = ISO8601DateFormatter().format(Date())
)

val credential = MedicalCredential(
    id = UUID.randomUUID().toString(),
    type = "BloodPressureReading",
    issuer = "Healthcare Provider XYZ",
    issuanceDate = Date(),
    fhirResource = FHIRResource(
        resourceType = "Observation",
        id = observation.id,
        data = observation.toMap()
    )
)

lifecycleScope.launch {
    wallet.addCredential(credential)
        .onSuccess { id -> 
            Log.d("Wallet", "Credential stored: $id") 
        }
        .onFailure { error -> 
            Log.e("Wallet", "Failed to store", error) 
        }
}
```

## Common Patterns

### Require Authentication for Every Use

**iOS:**
```swift
let config = try WalletConfig(
    userAuthenticationRequired: true,
    authenticationTimeout: 0 // Require auth every time
)
```

**Android:**
```kotlin
val config = WalletConfig(
    userAuthenticationRequired = true,
    authenticationTimeoutSeconds = -1 // Require auth every time
)
```

### App Group Sharing (iOS Only)

```swift
// Share credentials between main app and extensions
let config = try WalletConfig(
    serviceName: "com.myapp.wallet",
    accessGroup: "group.com.myapp.shared"
)

let wallet = try WalletManager(config: config)
```

### Maximum Security Configuration

**iOS:**
```swift
let maxSecurityConfig = try WalletConfig(
    userAuthenticationRequired: true,
    authenticationTimeout: 0, // Auth for every use
    useSecureEnclaveWhenAvailable: true
)
```

**Android:**
```kotlin
val maxSecurityConfig = WalletConfig(
    userAuthenticationRequired = true,
    authenticationTimeoutSeconds = -1, // Auth for every use
    useStrongBoxWhenAvailable = true
)
```

### Convenience Configuration for Testing

**iOS:**
```swift
#if DEBUG
let testConfig = try WalletConfig(
    serviceName: "com.myapp.wallet.test",
    userAuthenticationRequired: false // Skip auth in tests
)
#endif
```

**Android:**
```kotlin
val testConfig = if (BuildConfig.DEBUG) {
    WalletConfig.DEBUG
} else {
    WalletConfig.DEFAULT
}
```

## Migration from Previous Version

If you're upgrading from the previous version without configuration:

**iOS - Before:**
```swift
let wallet = WalletManager.shared
```

**iOS - After (same behavior):**
```swift
let wallet = WalletManager.shared // Uses default config
```

**Android - Before:**
```kotlin
val wallet = WalletManager.getInstance(context)
```

**Android - After (same behavior):**
```kotlin
val wallet = WalletManager.getInstance(context) // Uses default config
```

## Best Practices

1. **Use Default Configuration for Most Apps**
   - Provides secure defaults aligned with EU Digital Identity Wallet
   - Automatically uses hardware-backed security when available

2. **Enable User Authentication in Production**
   - Always require biometric/PIN for production apps
   - Use reasonable timeout (30-60 seconds)

3. **Use Debug Configuration Only in Development**
   - Disable authentication for easier testing
   - Never ship with authentication disabled

4. **Validate Configuration**
   - Service names are validated (no ":" character)
   - Timeout values are validated
   - Errors thrown for invalid configuration

5. **Check Hardware Capabilities**
   - Query Secure Enclave/StrongBox availability
   - Graceful fallback to software keys

## Security Considerations

- **Secure Enclave (iOS)**: Keys never leave secure hardware
- **StrongBox (Android 9+)**: Hardware security module protection
- **Biometric Authentication**: Required for key operations when enabled
- **Authentication Timeout**: Balance security and user experience
- **Access Groups (iOS)**: Only use for trusted app families
- **Key Isolation**: Each service name creates isolated key storage

## Troubleshooting

### iOS: "Service name contains :" error
```swift
// ❌ Invalid
let config = try WalletConfig(serviceName: "com.app:wallet")

// ✅ Valid
let config = try WalletConfig(serviceName: "com.app.wallet")
```

### Android: Authentication Required But No Timeout
```kotlin
// Configure with timeout
val config = WalletConfig(
    userAuthenticationRequired = true,
    authenticationTimeoutSeconds = 30 // Must specify timeout
)
```

### Keys Not Accessible After Biometric Change
- Keys with `.biometryCurrentSet` are invalidated when biometrics change
- User must re-initialize wallet
- Consider using `.biometryAny` for persistent keys (less secure)

## References

- [EU Digital Identity Wallet iOS Library](https://github.com/eu-digital-identity-wallet/eudi-lib-ios-wallet-kit)
- [EU Digital Identity Wallet Android Library](https://github.com/eu-digital-identity-wallet/eudi-lib-android-wallet-core)
- [EUDI Alignment Analysis](EUDI_ALIGNMENT_ANALYSIS.md)
