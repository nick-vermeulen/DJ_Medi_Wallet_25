# DJ Medi Wallet - Android

## Overview
Android application for DJ_Medi_Wallet_25, a medical data wallet based on the EU Digital Identity Wallet project.

## Requirements
- Android 8.0 (API level 26)+
- Kotlin 1.7+
- Gradle 7.0+

## Features
- Secure storage of medical credentials using Android Keystore
- Support for FHIR R4 medical records
- SNOMED CT code integration
- Biometric authentication (Fingerprint/Face unlock)
- Encrypted credential storage
- Verifiable credential presentations

## Project Structure
```
app/src/main/java/com/djmediwallet/
├── core/                # Core wallet functionality
│   ├── WalletManager.kt
│   ├── SecurityManager.kt
│   └── CredentialManager.kt
├── models/              # Data models
│   ├── fhir/           # FHIR resource models
│   └── credential/     # Credential models
├── storage/            # Secure storage layer
├── ui/                 # User interface
└── utilities/          # Helper utilities
```

## Setup Instructions

### 1. Open Android Studio
```bash
cd android/DJMediWallet
# Open in Android Studio
```

### 2. Sync Gradle
- Android Studio will prompt to sync Gradle
- Allow the sync to complete

### 3. Build and Run
- Select a device or emulator
- Click Run button or Shift+F10

## Build Configuration

### build.gradle (Project level)
```gradle
buildscript {
    ext.kotlin_version = "1.7.20"
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath "com.android.tools.build:gradle:7.3.0"
        classpath "org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlin_version"
    }
}
```

### build.gradle (App level)
```gradle
plugins {
    id 'com.android.application'
    id 'kotlin-android'
}

android {
    compileSdk 33
    
    defaultConfig {
        applicationId "com.djmediwallet"
        minSdk 26
        targetSdk 33
        versionCode 1
        versionName "1.0"
    }
    
    buildTypes {
        release {
            minifyEnabled false
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
    }
    
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }
    
    kotlinOptions {
        jvmTarget = '1.8'
    }
}

dependencies {
    implementation "org.jetbrains.kotlin:kotlin-stdlib:$kotlin_version"
    implementation 'androidx.core:core-ktx:1.9.0'
    implementation 'androidx.appcompat:appcompat:1.6.0'
    implementation 'com.google.android.material:material:1.8.0'
    implementation 'androidx.biometric:biometric:1.1.0'
    implementation 'org.jetbrains.kotlinx:kotlinx-coroutines-android:1.6.4'
}
```

## Security Features

### Android Keystore
Private keys are stored in Android Keystore:
- Hardware-backed security when available
- Biometric authentication support
- Keys never extractable
- Automatic key deletion on app removal

### Data Encryption
All medical credentials are encrypted at rest:
- AES-256 encryption
- Keys stored in Android Keystore
- Secure file storage in app private directory

### Biometric Authentication
Optional biometric authentication:
- Fingerprint scanner
- Face unlock
- PIN/Pattern fallback

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
```kotlin
val walletManager = WalletManager.getInstance(context)

lifecycleScope.launch {
    val result = walletManager.initializeWallet()
    result.onSuccess {
        Log.d("Wallet", "Initialized successfully")
    }.onFailure { error ->
        Log.e("Wallet", "Initialization failed", error)
    }
}
```

### Add Credential
```kotlin
val credential = MedicalCredential(
    id = UUID.randomUUID().toString(),
    type = "VaccinationRecord",
    issuer = "Healthcare Provider",
    issuanceDate = Date(),
    fhirResource = fhirResource
)

lifecycleScope.launch {
    val result = walletManager.addCredential(credential)
    result.onSuccess { id ->
        Log.d("Wallet", "Credential added: $id")
    }.onFailure { error ->
        Log.e("Wallet", "Failed to add credential", error)
    }
}
```

### Retrieve Credentials
```kotlin
lifecycleScope.launch {
    val result = walletManager.getAllCredentials()
    result.onSuccess { credentials ->
        Log.d("Wallet", "Found ${credentials.size} credentials")
    }.onFailure { error ->
        Log.e("Wallet", "Failed to retrieve credentials", error)
    }
}
```

### Create Presentation
```kotlin
val credentialIds = listOf("id1", "id2")

lifecycleScope.launch {
    val result = walletManager.createPresentation(credentialIds)
    result.onSuccess { presentation ->
        Log.d("Wallet", "Presentation created: ${presentation.id}")
    }.onFailure { error ->
        Log.e("Wallet", "Failed to create presentation", error)
    }
}
```

## Testing
Run unit tests:
```bash
./gradlew test
```

Run instrumented tests:
```bash
./gradlew connectedAndroidTest
```

## Permissions
Required permissions in AndroidManifest.xml:
```xml
<uses-permission android:name="android.permission.USE_BIOMETRIC" />
<uses-permission android:name="android.permission.INTERNET" />
```

## Privacy & Compliance
- GDPR compliant data handling
- User consent management
- Right to be forgotten (credential deletion)
- Minimal data disclosure
- Audit trail for access

## License
See LICENSE file in root directory.
