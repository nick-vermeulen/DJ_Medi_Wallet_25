# DJ Medi Wallet - iOS

## Overview
iOS application for DJ_Medi_Wallet_25, a medical data wallet based on the EU Digital Identity Wallet project.

## Requirements
- iOS 14.0+
- Xcode 13.0+
- Swift 5.5+

## Features
- Secure storage of medical credentials using Keychain
- Support for FHIR R4 medical records
- SNOMED CT code integration
- Biometric authentication (Face ID/Touch ID)
- Encrypted credential storage
- Verifiable credential presentations

## Project Structure
```
DJMediWallet/
├── Application/          # App lifecycle
├── Core/                # Core wallet functionality
│   ├── WalletManager.swift
│   ├── SecurityManager.swift
│   └── CredentialManager.swift
├── Models/              # Data models
│   ├── FHIR/           # FHIR resource models
│   └── Credential/     # Credential models
├── Storage/            # Secure storage layer
├── UI/                 # User interface
└── Utilities/          # Helper utilities
```

## Setup Instructions

### 1. Open Xcode Project
```bash
cd ios/DJMediWallet
open DJMediWallet.xcodeproj
```

### 2. Configure Signing
- Select the DJMediWallet target
- Go to Signing & Capabilities
- Select your development team
- Update bundle identifier if needed

### 3. Build and Run
- Select a simulator or device
- Press Cmd+R to build and run

## Security Features

### Keychain Storage
Private keys are stored in the iOS Keychain with biometric protection:
- Face ID/Touch ID authentication required
- Keys never leave the secure enclave
- Automatic key deletion on app removal

### Data Encryption
All medical credentials are encrypted at rest using AES-256:
- Encryption keys stored in Keychain
- Data protected with device passcode
- Secure file storage

### Biometric Authentication
Optional biometric authentication for sensitive operations:
- Face ID on supported devices
- Touch ID fallback
- Device passcode as alternative

## FHIR Integration

### Supported Resources
- Patient (demographics)
- Observation (vital signs, lab results)
- Condition (diagnoses)
- MedicationStatement (medications)
- AllergyIntolerance (allergies)
- Immunization (vaccinations)
- DiagnosticReport (reports)
- DocumentReference (documents)

### SNOMED CT Codes
Medical terminology standardization:
- System URI: http://snomed.info/sct
- Validation of code format
- Extraction from FHIR resources
- Display name resolution

## API Usage

### Initialize Wallet
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

### Add Credential
```swift
let credential = MedicalCredential(
    id: UUID().uuidString,
    type: "VaccinationRecord",
    issuer: "Healthcare Provider",
    issuanceDate: Date(),
    fhirResource: fhirResource
)

walletManager.addCredential(credential) { result in
    switch result {
    case .success(let id):
        print("Credential added: \(id)")
    case .failure(let error):
        print("Error: \(error)")
    }
}
```

### Retrieve Credentials
```swift
walletManager.getAllCredentials { result in
    switch result {
    case .success(let credentials):
        print("Found \(credentials.count) credentials")
    case .failure(let error):
        print("Error: \(error)")
    }
}
```

### Create Presentation
```swift
let credentialIds = ["id1", "id2"]

walletManager.createPresentation(credentialIds: credentialIds) { result in
    switch result {
    case .success(let presentation):
        print("Presentation created: \(presentation.id)")
    case .failure(let error):
        print("Error: \(error)")
    }
}
```

## Testing
Run unit tests:
```bash
xcodebuild test -scheme DJMediWallet -destination 'platform=iOS Simulator,name=iPhone 14'
```

## Privacy & Compliance
- GDPR compliant data handling
- User consent management
- Right to be forgotten (credential deletion)
- Minimal data disclosure
- Audit trail for access

## License
See LICENSE file in root directory.
