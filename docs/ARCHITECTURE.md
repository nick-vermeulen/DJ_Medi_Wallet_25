# DJ_Medi_Wallet_25 Architecture

## Overview
DJ_Medi_Wallet_25 is a medical data wallet based on the EU Digital Identity Wallet Architecture Reference Framework (ARF). It provides secure storage and management of medical records using FHIR and SNOMED CT standards.

## Architecture Reference Framework (ARF) Alignment

### Core Components

#### 1. Wallet Instance
The mobile application (iOS/Android) that runs on the user's device and manages medical credentials.

**Key Features:**
- Secure local storage of medical credentials
- Cryptographic operations for signing and verification
- User authentication and authorization
- Credential presentation to healthcare providers

#### 2. Credential Storage
Encrypted storage for medical credentials and private keys.

**Implementation:**
- iOS: Keychain Services for secure key storage
- Android: Android Keystore System
- Encrypted database for credential data

#### 3. Trust Framework
Establishes trust relationships between wallet, issuers, and verifiers.

**Components:**
- Certificate validation
- Trust anchor management
- Revocation checking

#### 4. Credential Formats
Support for W3C Verifiable Credentials and ISO/IEC 18013-5 mDL formats adapted for medical data.

**Medical Credential Types:**
- Patient demographics
- Vaccination records
- Prescription history
- Lab results
- Allergy information
- Medical conditions

### Security Architecture

#### Cryptographic Keys
- **Device Key Pair**: Generated during wallet initialization
- **Credential Keys**: Per-credential key pairs for selective disclosure
- **Key Storage**: Hardware-backed security when available

#### Data Protection
- **At Rest**: AES-256 encryption for stored credentials
- **In Transit**: TLS 1.3 for network communication
- **Selective Disclosure**: Zero-knowledge proofs for privacy

#### Authentication Mechanisms
- Biometric authentication (Face ID, Touch ID, Fingerprint)
- PIN/Passcode fallback
- Multi-factor authentication support

### Medical Data Standards

#### FHIR Integration
- **Version**: FHIR R4 (4.0.1)
- **Resources**: Patient, Observation, Condition, MedicationStatement, AllergyIntolerance, Immunization, DiagnosticReport, DocumentReference
- **Format**: JSON
- **Validation**: FHIR resource validation against schemas

#### SNOMED CT Integration
- **Purpose**: Standardized clinical terminology
- **Usage**: Coding diagnoses, procedures, findings, and substances
- **System URI**: http://snomed.info/sct
- **Integration**: Used within FHIR CodeableConcept elements

### Application Architecture

#### iOS App (Swift)

```
DJMediWallet/
├── Application/
│   ├── AppDelegate.swift
│   └── SceneDelegate.swift
├── Core/
│   ├── WalletManager.swift
│   ├── SecurityManager.swift
│   └── CredentialManager.swift
├── Models/
│   ├── FHIR/
│   │   ├── Patient.swift
│   │   ├── Observation.swift
│   │   ├── Condition.swift
│   │   └── MedicationStatement.swift
│   └── Credential/
│       └── MedicalCredential.swift
├── Storage/
│   ├── SecureStorage.swift
│   └── DatabaseManager.swift
├── UI/
│   ├── Views/
│   ├── ViewModels/
│   └── Components/
└── Utilities/
    ├── Cryptography.swift
    └── Extensions.swift
```

#### Android App (Kotlin)

```
DJMediWallet/
├── app/src/main/java/com/djmediwallet/
│   ├── application/
│   │   └── MediWalletApplication.kt
│   ├── core/
│   │   ├── WalletManager.kt
│   │   ├── SecurityManager.kt
│   │   └── CredentialManager.kt
│   ├── models/
│   │   ├── fhir/
│   │   │   ├── Patient.kt
│   │   │   ├── Observation.kt
│   │   │   ├── Condition.kt
│   │   │   └── MedicationStatement.kt
│   │   └── credential/
│   │       └── MedicalCredential.kt
│   ├── storage/
│   │   ├── SecureStorage.kt
│   │   └── DatabaseManager.kt
│   ├── ui/
│   │   ├── views/
│   │   ├── viewmodels/
│   │   └── components/
│   └── utilities/
│       ├── Cryptography.kt
│       └── Extensions.kt
└── app/src/main/res/
```

### Data Flow

#### Credential Issuance
1. User requests medical record from healthcare provider
2. Provider authenticates user identity
3. Provider issues signed FHIR resource as verifiable credential
4. Wallet receives and validates credential
5. Credential stored securely in wallet

#### Credential Presentation
1. Healthcare provider requests specific medical information
2. User reviews request and consents
3. Wallet creates presentation with selective disclosure
4. Presentation signed with wallet key
5. Provider verifies presentation and extracts data

### Privacy and Compliance

#### GDPR Compliance
- User consent management
- Right to be forgotten (credential deletion)
- Data minimization
- Purpose limitation

#### HIPAA Considerations
- Secure storage and transmission
- Access controls and audit logs
- Breach notification procedures
- Business associate agreements

#### Additional Privacy Features
- Minimal disclosure protocols
- Pseudonymization options
- User-controlled data sharing
- Audit trail for credential access

### Interoperability

#### Standards Support
- **W3C**: Verifiable Credentials, Decentralized Identifiers (DIDs)
- **OpenID**: OpenID Connect for credential issuance and presentation
- **ISO/IEC**: 18013-5 mobile Driver License format (adapted for medical)
- **HL7**: FHIR R4 for medical data representation

#### Healthcare System Integration
- EHR/EMR system connectivity
- HL7 v2 message translation
- IHE profiles support
- SMART on FHIR authorization

### Future Enhancements
- Cross-border medical data exchange
- Emergency access protocols
- Family/caregiver access delegation
- Integration with national health databases
- Blockchain-based credential verification
- AI-powered health insights

## References
- EU Digital Identity Wallet Architecture Reference Framework: https://github.com/eu-digital-identity-wallet
- FHIR Specification: http://hl7.org/fhir/
- SNOMED International: https://www.snomed.org/
- W3C Verifiable Credentials: https://www.w3.org/TR/vc-data-model/
