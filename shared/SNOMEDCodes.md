# SNOMED CT Codes for DJ_Medi_Wallet_25

## Overview
SNOMED CT (Systematized Nomenclature of Medicine -- Clinical Terms) is a comprehensive clinical terminology system used in DJ_Medi_Wallet_25 for standardized medical coding.

## Purpose
- Standardize clinical terminology across the medical wallet
- Enable interoperability with healthcare systems
- Support clinical decision support
- Facilitate accurate health data exchange

## Common SNOMED CT Codes Used

### Body Systems
- `123037004` - Body structure
- `91723000` - Anatomical structure
- `442083009` - Anatomical or acquired body structure

### Clinical Findings
- `404684003` - Clinical finding
- `413350009` - Finding with explicit context
- `118956008` - Body structure, altered from its original anatomical structure
- `64572001` - Disease
- `272379006` - Event

### Procedures
- `71388002` - Procedure
- `386053000` - Evaluation procedure
- `277132007` - Therapeutic procedure
- `363679005` - Imaging

### Substances
- `105590001` - Substance
- `373873005` - Pharmaceutical / biologic product
- `410942007` - Drug or medicament

### Common Clinical Conditions
- `38341003` - Hypertensive disorder
- `73211009` - Diabetes mellitus
- `195967001` - Asthma
- `49436004` - Atrial fibrillation
- `13645005` - Chronic obstructive lung disease
- `22298006` - Myocardial infarction

### Vital Signs
- `75367002` - Blood pressure
- `364075005` - Heart rate
- `386725007` - Body temperature
- `86290005` - Respiratory rate
- `27113001` - Body weight
- `50373000` - Body height

### Allergies
- `609328004` - Allergic disposition
- `420134006` - Propensity to adverse reaction
- `416098002` - Drug allergy
- `414285001` - Food allergy
- `232347008` - Dander allergy

### Immunizations
- `127785005` - Administration of vaccine product
- `170370000` - Administration of first dose of vaccine product
- `170371001` - Administration of second dose of vaccine product
- `170378007` - Administration of booster dose of vaccine product

## SNOMED CT Code Structure

SNOMED CT codes are numeric identifiers with the following characteristics:
- 6 to 18 digits in length
- Unique globally
- Never reused
- Organized in hierarchical relationships

## Example Usage in Medical Records

### Diagnosis Example
```json
{
  "code": {
    "coding": [
      {
        "system": "http://snomed.info/sct",
        "code": "38341003",
        "display": "Hypertensive disorder"
      }
    ]
  }
}
```

### Procedure Example
```json
{
  "code": {
    "coding": [
      {
        "system": "http://snomed.info/sct",
        "code": "71388002",
        "display": "Procedure"
      }
    ]
  }
}
```

### Allergy Example
```json
{
  "code": {
    "coding": [
      {
        "system": "http://snomed.info/sct",
        "code": "416098002",
        "display": "Drug allergy"
      }
    ]
  },
  "substance": {
    "coding": [
      {
        "system": "http://snomed.info/sct",
        "code": "387207008",
        "display": "Penicillin"
      }
    ]
  }
}
```

## Integration with FHIR

SNOMED CT codes are used within FHIR resources in the `coding` element:
- System: `http://snomed.info/sct`
- Code: The SNOMED CT concept ID
- Display: Human-readable description

## References
- SNOMED International: https://www.snomed.org/
- SNOMED CT Browser: https://browser.ihtsdotools.org/
- FHIR SNOMED CT Code System: http://snomed.info/sct
