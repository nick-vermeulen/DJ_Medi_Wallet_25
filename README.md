# DJ_Medi_Wallet_25

Medical Data Wallet for Digital Jersey Hackathon

## Overview

DJ_Medi_Wallet_25 is a secure medical data wallet based on the EU Digital Identity Wallet Architecture Reference Framework (ARF). It provides a mobile solution for storing and managing medical records using FHIR (Fast Healthcare Interoperability Resources) and SNOMED CT (Systematized Nomenclature of Medicine -- Clinical Terms) standards.

## Features

### 🔐 Security & Privacy
- **Hardware-backed key storage**: iOS Keychain and Android Keystore
- **Biometric authentication**: Face ID, Touch ID, Fingerprint
- **End-to-end encryption**: AES-256 for credential storage
- **Zero-knowledge proofs**: Selective disclosure capabilities
- **GDPR compliant**: Privacy-first architecture

### 🏥 Medical Standards
- **FHIR R4 Support**: Full implementation of FHIR resources
- **SNOMED CT Integration**: Standardized medical terminology
- **Interoperable**: Compatible with healthcare systems worldwide
- **Verifiable Credentials**: W3C standard implementation

### 📱 Mobile Apps
- **iOS**: Swift-based native application (iOS 14.0+)
- **Android**: Kotlin-based native application (Android 8.0+)

## Project Structure

```
DJ_Medi_Wallet_25/
├── ios/                    # iOS application
│   └── DJMediWallet/
│       ├── Core/          # Wallet core functionality
│       ├── Models/        # FHIR and credential models
│       ├── Storage/       # Secure storage layer
│       └── UI/            # User interface
├── android/               # Android application
│   └── DJMediWallet/
│       └── app/src/main/java/com/djmediwallet/
│           ├── core/      # Wallet core functionality
│           ├── models/    # FHIR and credential models
│           ├── storage/   # Secure storage layer
│           └── ui/        # User interface
├── docs/                  # Documentation
│   └── ARCHITECTURE.md    # Architecture overview
└── shared/                # Shared documentation
    ├── FHIRModels.md     # FHIR data models
    └── SNOMEDCodes.md    # SNOMED CT codes
```

## Architecture

DJ_Medi_Wallet_25 follows the EU Digital Identity Wallet Architecture Reference Framework (ARF):

### Core Components

1. **Wallet Instance**: Mobile application managing medical credentials
2. **Credential Storage**: Encrypted local storage with hardware-backed keys
3. **Security Layer**: Cryptographic operations and authentication
4. **Trust Framework**: Certificate validation and trust management

### Data Standards

- **FHIR R4**: Healthcare data representation
  - Patient demographics
  - Observations (vital signs, lab results)
  - Conditions (diagnoses)
  - Medications
  - Allergies
  - Immunizations
  
- **SNOMED CT**: Clinical terminology
  - Standardized medical codes
  - Hierarchical relationships
  - Interoperability support

See [ARCHITECTURE.md](docs/ARCHITECTURE.md) for detailed architecture documentation.

## Supported FHIR Resources

| Resource | Description |
|----------|-------------|
| Patient | Demographics and identifiers |
| Observation | Vital signs and lab results |
| Condition | Diagnoses and health concerns |
| MedicationStatement | Medication history |
| AllergyIntolerance | Allergies and reactions |
| Immunization | Vaccination records |
| DiagnosticReport | Lab and imaging reports |
| DocumentReference | Clinical documents |

## Getting Started

### iOS Development

#### Requirements
- macOS 12.0+
- Xcode 13.0+
- iOS 14.0+ device or simulator

#### Setup
```bash
cd ios/DJMediWallet
open DJMediWallet.xcodeproj
# Configure signing in Xcode
# Build and run (Cmd+R)
```

See [iOS README](ios/DJMediWallet/README.md) for detailed instructions.

### Android Development

#### Requirements
- Android Studio Arctic Fox or later
- Android SDK 26+
- Kotlin 1.7+

#### Setup
```bash
cd android/DJMediWallet
# Open in Android Studio
# Sync Gradle
# Build and run (Shift+F10)
```

See [Android README](android/DJMediWallet/README.md) for detailed instructions.

## Usage Examples

### Initialize Wallet

**iOS (Swift)**
```swift
let walletManager = WalletManager.shared

walletManager.initializeWallet { result in
    switch result {
    case .success:
        print("Wallet initialized")
    case .failure(let error):
        print("Error: \(error)")
    }
}
```

**Android (Kotlin)**
```kotlin
val walletManager = WalletManager.getInstance(context)

lifecycleScope.launch {
    walletManager.initializeWallet()
        .onSuccess { println("Wallet initialized") }
        .onFailure { error -> println("Error: $error") }
}
```

### Store Medical Record

**iOS (Swift)**
```swift
let credential = MedicalCredential(
    id: UUID().uuidString,
    type: "VaccinationRecord",
    issuer: "Healthcare Provider",
    issuanceDate: Date(),
    fhirResource: vaccinationFHIR
)

walletManager.addCredential(credential) { result in
    // Handle result
}
```

**Android (Kotlin)**
```kotlin
val credential = MedicalCredential(
    id = UUID.randomUUID().toString(),
    type = "VaccinationRecord",
    issuer = "Healthcare Provider",
    issuanceDate = Date(),
    fhirResource = vaccinationFHIR
)

lifecycleScope.launch {
    walletManager.addCredential(credential)
}
```

## FHIR Integration

### Example: Blood Pressure Observation

```json
{
  "resourceType": "Observation",
  "status": "final",
  "code": {
    "coding": [{
      "system": "http://loinc.org",
      "code": "85354-9",
      "display": "Blood pressure panel"
    }]
  },
  "component": [
    {
      "code": {
        "coding": [{
          "system": "http://loinc.org",
          "code": "8480-6",
          "display": "Systolic blood pressure"
        }]
      },
      "valueQuantity": {
        "value": 120,
        "unit": "mmHg"
      }
    }
  ]
}
```

### Example: SNOMED CT Code

```json
{
  "code": {
    "coding": [{
      "system": "http://snomed.info/sct",
      "code": "38341003",
      "display": "Hypertensive disorder"
    }]
  }
}
```

## Security

### Cryptographic Operations
- **Key Generation**: P-256 (iOS) / EC 256-bit (Android)
- **Signing**: ECDSA with SHA-256
- **Encryption**: AES-256-CBC
- **Key Storage**: Hardware-backed when available

### Authentication
- Biometric (Face ID, Touch ID, Fingerprint)
- Device passcode fallback
- No credentials stored on servers

### Data Protection
- Encrypted at rest
- Encrypted in transit (TLS 1.3)
- Secure enclave usage (iOS)
- Hardware keystore (Android)

## Privacy & Compliance

- ✅ GDPR compliant
- ✅ HIPAA considerations
- ✅ User consent management
- ✅ Right to be forgotten
- ✅ Data minimization
- ✅ Purpose limitation
- ✅ Audit trail

## Testing

### iOS
```bash
cd ios/DJMediWallet
xcodebuild test -scheme DJMediWallet \
  -destination 'platform=iOS Simulator,name=iPhone 14'
```

### Android
```bash
cd android/DJMediWallet
./gradlew test
./gradlew connectedAndroidTest
```

## Documentation

- [Architecture Overview](docs/ARCHITECTURE.md)
- [FHIR Data Models](shared/FHIRModels.md)
- [SNOMED CT Codes](shared/SNOMEDCodes.md)
- [iOS Documentation](ios/DJMediWallet/README.md)
- [Android Documentation](android/DJMediWallet/README.md)

## References

- **EU Digital Identity Wallet**: https://github.com/eu-digital-identity-wallet
- **FHIR Specification**: http://hl7.org/fhir/
- **SNOMED International**: https://www.snomed.org/
- **W3C Verifiable Credentials**: https://www.w3.org/TR/vc-data-model/

## License

See [LICENSE](LICENSE) file for details.

## Contributing

This is a hackathon project for Digital Jersey. Contributions should align with the EU Digital Identity Wallet ARF principles and healthcare data standards.

## Support

For questions or issues, please open an issue in this repository.

---

**Built for Digital Jersey Hackathon 2025**
