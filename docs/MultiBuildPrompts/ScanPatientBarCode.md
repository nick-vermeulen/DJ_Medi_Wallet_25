## ID Wallet Integration Specification

## Overview
An ID card management system that allows users to scan, store, and display identity cards, membership cards, and loyalty cards as barcodes. Uses Apple's native DataScannerViewController for OCR and barcode scanning. The system is location-aware to handle region-specific patient IDs in the "Healthcare" category, detecting the user's country (e.g., UK for NHS Number, Jersey for demographic-based identification via Jersey Health and Care Index (JHCI), or Guernsey for Social Security-linked identification) to suggest or validate the appropriate ID format during addition or scanning. For Jersey-based hospitals, supports scanning of admission wristband barcodes to set as the default patient ID number.

## Core Features
- **Scan & Add Cards**: Camera-based scanning with OCR for text and barcode recognition, customized prompts based on detected location (e.g., "Scan your NHS Number barcode" in the UK)
- **Organize by Categories**: User-defined categories (Healthcare, Loyalty Cards, etc.), with location-specific sub-guidance for Healthcare
- **Display Barcodes**: Generate and display Code128 barcodes for scanning, with fallback to text display for non-barcode IDs (e.g., demographic details in Jersey/Guernsey)
- **Manage Cards**: Edit, delete, and categorize stored cards
- **Search**: Search cards by name or category
- **Location Detection**: Uses CoreLocation to determine country code (e.g., GB for UK, JE for Jersey, GG for Guernsey) and tailor Healthcare ID handling
- **Jersey Hospital Wristband Support**: Dedicated scanning for wristband barcodes to set as default patient ID in Healthcare category

## Data Models

### IDCard
```swift
struct IDCard: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String        // e.g., "NHS Number" or "Jersey Health ID"
    var number: String      // The actual ID number (e.g., 10-digit NHS Number) or concatenated details (e.g., "Name: John Doe, DOB: 01/01/1980" for Jersey/Guernsey)
    var category: String    // e.g., "Healthcare"
    var region: String?     // Optional: Detected country code (e.g., "GB", "JE", "GG") for validation
    var isDefault: Bool = false  // Flag to mark as default patient ID (e.g., from wristband scan)
}
```

### Storage
- **@AppStorage("idCards")**: Array of IDCard objects
- **@AppStorage("categories")**: Array of category strings
- Default categories: ["Healthcare", "Loyalty Cards", "Memberships", "Insurance"]

## Required Frameworks
```swift
import SwiftUI
import CoreImage.CIFilterBuiltins  // For barcode generation
import VisionKit                    // For DataScannerViewController
import AVFoundation                 // For camera support
import CoreLocation                 // For location detection to handle region-specific IDs
```

## Key Components

### 1. Cards Display View
- List grouped by category
- Search functionality
- Tap to show barcode
- Empty state with direction to Settings
- For Healthcare cards, display region-specific notes (e.g., "UK NHS Number – Verify with Mod 11 checksum"); highlight default ID if set

### 2. Settings View
- Add Card button (opens scanner)
- Category management (add/delete)
- Card management (edit/delete organized by category)
- Location-based toggle: Prompt user to allow location access for accurate Healthcare ID suggestions
- Jersey Hospital Section: If location is JE (Jersey), show a "Scan Hospital Wristband" button that opens the scanner view specifically for wristbands. Upon successful scan, auto-create or update an IDCard in "Healthcare" with name "Jersey Patient ID", set number to scanned barcode value, mark isDefault = true, and use it as the default for any patient-related features (e.g., override other Healthcare IDs when displaying or sharing)

### 3. Scanner View
- Uses DataScannerViewController
- Recognizes text and barcodes
- Auto-fills barcode numbers
- Manual entry fallback
- Instructional overlay, customized by location:
  - UK (GB): "Scan your NHS Number barcode (10-digit format)"
  - Jersey (JE): "Scan or capture details from your health card (e.g., name, DOB, address for JHCI matching)" or "Scan wristband barcode" if triggered from wristband button
  - Guernsey (GG): "Scan or capture your Social Security card or health details"
- The form should show scanned text as tappable suggestions
- Include category selection and card name/number fields
- Start scanning automatically when view appears
- On load, request location permission and use CLLocationManager to get country code; adjust prompts accordingly
- For wristband scan: Auto-set category to "Healthcare", name to "Jersey Patient ID", and flag as default

### 4. Barcode Display View
- Shows card name and category
- Generates Code128 barcode using CIFilter.code128BarcodeGenerator (for numeric IDs like NHS Number; fallback to QR code or text for non-numeric details in Jersey/Guernsey)
- Displays the barcode on a white background with rounded corners and shadow
- Shows the number below in monospaced font
- Includes a GroupBox at the bottom with a brightness slider
- Auto-sets screen brightness to 100% when view appears
- Restores original brightness when dismissed
- Uses standard navigation with a "Done" button
- For non-barcode regions (e.g., Jersey/Guernsey), display scannable QR code encoding demographic details if no native barcode; prioritize default wristband ID if set

### 5. Add/Edit Card Views
- Form-based input
- Category selection with checkmarks
- Scanner integration
- Tappable scanned text suggestions
- Location-based validation:
  - For UK: Suggest "NHS Number" name, validate 10-digit format with Mod 11 checksum (implement a helper function)
  - For Jersey: Suggest capturing multiple fields (name, DOB, address) as a single "number" string for JHCI consistency; if wristband, validate as barcode number
  - For Guernsey: Suggest "Social Security Number" or local health ID, with text OCR for details
- When saving, if isDefault = true, ensure only one default per category (unset others)

## Integration Prompts

### Step 1: Add Data Model & Storage
```
Add this data model to the app:

struct IDCard: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var number: String
    var category: String
    var region: String?  // e.g., "GB", "JE", "GG"
    var isDefault: Bool = false  // For default patient ID (e.g., Jersey wristband)
}

Also add these imports at the top:
import CoreImage.CIFilterBuiltins
import VisionKit
import AVFoundation
import CoreLocation  // For region detection
```

### Step 2: Add Settings Section
```
In the Settings tab, add a new section called "ID Cards" with a navigation link that goes to a new view called IDCardSettingsView. This view should have:

- A button to "Add Card" 
- A "Categories" section showing all categories with card counts, with swipe-to-delete
- A button to add new categories
- A "Manage Cards" section with disclosure groups organized by category, showing each card with edit button and swipe-to-delete
- A toggle for "Enable Location for Healthcare IDs" to customize prompts based on country (UK: NHS Number, Jersey: JHCI details, Guernsey: Social Security details)
- If location is Jersey (JE), add a "Jersey Hospital" subsection with a "Scan Wristband" button that opens AddCardView in wristband mode, scans barcode, and sets the resulting card as default (isDefault = true) for patient numbers in Healthcare

Use @AppStorage("idCards") for storing cards array and @AppStorage("categories") for categories array. Default categories should be: Healthcare, Loyalty Cards, Memberships, Insurance.
```

### Step 3: Add Scanner Functionality
```
Create an AddCardView that opens with a camera scanner using DataScannerViewController. The scanner should:

- Recognize text and barcodes
- Auto-fill the card number field when a barcode is scanned
- Show an overlay with location-specific instructions: e.g., "Position NHS card in frame" for UK, "Capture health details" for Jersey/Guernsey, or "Scan hospital wristband barcode" for Jersey wristband mode
- Have a button "Enter Manually" that switches to a form view
- The form should show scanned text as tappable suggestions
- Include category selection and card name/number fields
- Start scanning automatically when view appears
- Use CLLocationManager to detect country code and adjust UI (requestWhenInUseAuthorization)
- In wristband mode (from Settings): Focus on barcode recognition, auto-set name to "Jersey Patient ID", category to "Healthcare", isDefault = true, and save as default patient number

Check DataScannerViewController.isSupported and .isAvailable before showing scanner.
```

### Step 4: Add Barcode Display
```
Create a BarcodeDisplayView that displays a card as a barcode. It should:

- Show the card name and category at the top
- Generate a Code128 barcode using CIFilter.code128BarcodeGenerator for numeric IDs (e.g., NHS Number); use QR code for text-based details (e.g., Jersey/Guernsey demographics)
- Display the barcode on a white background with rounded corners and shadow
- Show the number below in monospaced font
- Include a GroupBox at the bottom with a brightness slider
- Auto-set screen brightness to 100% when view appears
- Restore original brightness when dismissed
- Use standard navigation with a "Done" button
```

### Step 5: Add Cards Display Tab
```
Create a view under the profile setting in settings for displaying ID cards that shows:

- A searchable list grouped by category
- Each card showing name and number with a barcode icon
- Tapping a card opens BarcodeDisplayView
- Empty state: "No ID Cards" with description "Add your first card in Settings"
- Navigation title "ID Cards"
- Load cards from @AppStorage("idCards")
- Highlight or prioritize default patient ID in Healthcare if set

This view should be available from the Settings page in the profile section.
```

### Step 6: Add Edit Functionality
```
Create an EditCardView similar to AddCardView but without the scanner. It should:

- Pre-populate fields with existing card data
- Allow editing name, number, and category
- Update the card in the cards array when saved
- Use standard form layout with Cancel and Save buttons
- Apply location-based validation (e.g., check NHS Number format if region == "GB")
- Toggle isDefault option (ensure only one default per category)
```

## Technical Requirements

### Permissions
- Camera access (automatic prompt by DataScannerViewController)
- Location access (requestWhenInUseAuthorization for country detection)

### Barcode Generation
```swift
func generateBarcode(from string: String) -> UIImage? {
    let context = CIContext()
    let filter = CIFilter.code128BarcodeGenerator()
    filter.message = Data(string.utf8)
    
    if let outputImage = filter.outputImage {
        let scaleX = 300.0 / outputImage.extent.width
        let scaleY = 100.0 / outputImage.extent.height
        let transformedImage = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        
        if let cgImage = context.createCGImage(transformedImage, from: transformedImage.extent) {
            return UIImage(cgImage: cgImage)
        }
    }
    return nil
}
```

### NHS Number Validation (for UK)
```swift
func isValidNHSNumber(_ number: String) -> Bool {
    guard number.count == 10, let digits = Int(number) else { return false }
    // Implement Mod 11 checksum logic here
    // Step-by-step calculation as per standard
    var sum = 0
    for i in 0..<9 {
        let digit = Int(String(number[number.index(number.startIndex, offsetBy: i)]))!
        sum += digit * (10 - i)
    }
    let check = (11 - (sum % 11)) % 11
    let checkDigit = Int(String(number.last!))!
    return check == checkDigit && check != 10
}
```

### Scanner Implementation
```swift
- Use UIViewControllerRepresentable to wrap DataScannerViewController
- Implement DataScannerViewControllerDelegate
- Handle didTapOn and didAdd delegate methods
- Call startScanning() in makeUIViewController
- Call stopScanning() in dismantleUIViewController
- Integrate CLLocationManagerDelegate to get country code and customize overlay text
- Add wristbandMode parameter to view initializer for Jersey-specific handling
```

## UI/UX Guidelines Followed

- ✅ Native Apple components (List, Form, GroupBox)
- ✅ ContentUnavailableView for empty states
- ✅ Standard navigation patterns (NavigationStack, sheets)
- ✅ Proper toolbar placements (cancellationAction, confirmationAction)
- ✅ Swipe-to-delete gestures
- ✅ System colors and SF Symbols
- ✅ Search functionality with .searchable
- ✅ Proper form validation (disabled buttons)
- ✅ HIG-compliant scanner overlay
- ✅ Haptic feedback via system behaviors
- ✅ Accessibility labels on all interactive elements
- ✅ Location-specific prompts for inclusivity (e.g., handling non-numeric IDs in Jersey/Guernsey, wristband scanning)

## Testing Checklist

- [ ] Scan a barcode successfully (e.g., NHS in UK mode)
- [ ] Scan text from a card (e.g., demographics in Jersey mode)
- [ ] Add card manually without scanner
- [ ] Edit existing card
- [ ] Delete card via swipe
- [ ] Create new category
- [ ] Delete category
- [ ] Display barcode and verify it scans
- [ ] Brightness control works
- [ ] Search finds cards by name and category
- [ ] Empty states display correctly
- [ ] Data persists across app launches
- [ ] Location detection correctly customizes prompts (test with simulators for GB, JE, GG)
- [ ] Validate NHS Number checksum in UK
- [ ] Scan Jersey wristband from Settings, set as default, and verify it overrides other patient IDs

## Optional Enhancements

1. **QR Code Support**: Add QR code generation alongside Code128
2. **Card Images**: Allow users to capture/store card photos
3. **Expiry Dates**: Add expiry date field with notifications
4. **Card Sharing**: Export/import cards securely
5. **Favorites**: Pin frequently used cards to top
6. **Widgets**: Lock screen widget for quick access
7. **Secure Storage**: Use Keychain for sensitive cards
8. **Cloud Sync**: iCloud sync across devices
