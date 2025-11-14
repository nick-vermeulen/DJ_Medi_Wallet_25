# DJ Medi Wallet - User Interface Guide

## Overview

DJ Medi Wallet provides native mobile applications for iOS and Android that allow users to manually enter and review their medical records using FHIR-compliant forms with SNOMED CT standardized codes.

## Features

### 1. Medical Records List
- View all stored medical records
- Records organized by type (Vital Signs, Diagnoses, Medications)
- Quick view of key information for each record
- Tap any record to view full details

### 2. Add Medical Records
Select from three types of medical records:

#### Vital Signs / Observations
Enter measurements for:
- **Blood Pressure**: Systolic and diastolic readings in mmHg
- **Heart Rate**: Beats per minute (bpm)
- **Body Temperature**: In degrees Celsius
- **Weight**: In kilograms
- **Height**: In centimeters

All observations include:
- LOINC codes for standardized identification
- SNOMED CT codes where applicable
- Optional notes field
- Automatic timestamp

#### Diagnoses / Conditions
Select from common conditions:
- Hypertension
- Diabetes Mellitus Type 2
- Asthma
- Atrial Fibrillation
- COPD
- Myocardial Infarction
- Hyperlipidemia
- Osteoarthritis
- Depression
- Anxiety Disorder

Each condition includes:
- SNOMED CT code
- Severity level (Mild, Moderate, Severe)
- Clinical status (Active, Confirmed)
- Optional notes field

#### Medications
Select from common medications:
- Metformin
- Aspirin
- Lisinopril
- Atorvastatin
- Levothyroxine
- Metoprolol
- Amlodipine
- Omeprazole
- Simvastatin
- Losartan
- Albuterol
- Gabapentin

Each medication entry includes:
- SNOMED CT code
- Dosage amount
- Frequency (once daily, twice daily, etc.)
- Route of administration (Oral, Sublingual, Topical, etc.)
- Optional notes field

### 3. Record Details
View comprehensive information for each record:
- Record type and title
- Date recorded
- All FHIR resource fields
- SNOMED CT codes (when applicable)
- LOINC codes (for observations)
- Additional notes

## Platform-Specific Features

### iOS (SwiftUI)
- Native iOS design with system fonts and colors
- Tab-based navigation
- Smooth animations
- Support for iOS 14.0+
- Adaptive layouts for different screen sizes

### Android (Jetpack Compose)
- Material Design 3
- Bottom navigation bar
- Modern Android UI patterns
- Support for Android SDK 26+
- Adaptive layouts for different screen sizes

## Technical Implementation

### FHIR R4 Compliance
All records are created as valid FHIR R4 resources:

- **Observation**: For vital signs with proper categories, codes, and values
- **Condition**: For diagnoses with clinical status and verification status
- **MedicationStatement**: For medications with dosage and timing information

### SNOMED CT Integration
- All conditions use standardized SNOMED CT codes
- All medications use SNOMED CT codes
- Route of administration uses SNOMED CT codes
- Vital signs include SNOMED CT codes where defined

### LOINC Codes
- Blood pressure uses LOINC panel and component codes
- Each vital sign type has appropriate LOINC codes
- Ensures interoperability with healthcare systems

### Data Storage
- Records stored securely using WalletManager
- Encrypted at rest (placeholder implementation)
- JSON serialization with Gson (Android) and JSONEncoder (iOS)
- File-based storage in app sandbox

## Usage Guide

### Adding Your First Record

#### iOS
1. Open the app
2. Tap the "Add" tab at the bottom
3. Select record type (Vital Signs, Diagnosis, or Medication)
4. Fill in the required fields
5. Tap "Save Record"

#### Android
1. Open the app
2. Tap the "Add" navigation item at the bottom
3. Select record type using the chips at the top
4. Fill in the required fields
5. Tap "Save Record"

### Viewing Records

#### iOS
1. Records appear in the "Records" tab
2. Tap any record to see full details
3. Swipe back to return to the list

#### Android
1. Records appear in the "Records" screen
2. Tap any record to see full details
3. Press back button to return to the list

## Future Enhancements

Potential improvements for future versions:
- Barcode scanning for medications
- Photo attachments for documents
- Sharing records via QR codes
- Import from healthcare providers
- Export to PDF
- Cloud backup
- Biometric authentication for access
- More FHIR resource types (Allergies, Immunizations, etc.)
- Custom SNOMED code lookup
- Search and filter functionality
- Data visualization (charts for vital signs over time)

## Development

### Android
Location: `android/DJMediWallet/app/src/main/java/com/djmediwallet/ui/`

Key files:
- `MainActivity.kt` - Entry point
- `MediWalletApp.kt` - Main navigation structure
- `screens/` - Screen composables
- `components/` - Form components
- `viewmodels/` - State management

### iOS
Location: `ios/DJMediWallet/DJMediWallet/UI/`

Key files:
- `DJMediWalletApp.swift` - App entry point
- `Views/ContentView.swift` - Main navigation
- `Screens/` - Screen views
- `Components/` - Form components

## Standards Compliance

### FHIR R4
- Full compliance with FHIR R4 specification
- Valid JSON structures
- Proper resource types and fields
- ISO 8601 date formatting

### SNOMED CT
- International healthcare terminology
- Standardized clinical codes
- Enables semantic interoperability

### LOINC
- Logical Observation Identifiers Names and Codes
- Standard for identifying medical laboratory observations
- Used for all vital sign measurements

## Support

For issues or questions:
1. Check the main README.md
2. Review FHIR and SNOMED documentation in shared/ folder
3. Open an issue on GitHub
