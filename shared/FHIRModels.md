# FHIR Data Models for DJ_Medi_Wallet_25

## Overview
This document outlines the FHIR (Fast Healthcare Interoperability Resources) data models used in the DJ_Medi_Wallet_25 application.

## Supported FHIR Resources

### Patient
- Demographic information
- Identifiers (medical record numbers, national IDs)
- Contact information
- Emergency contacts

### Observation
- Vital signs (blood pressure, heart rate, temperature)
- Laboratory results
- Clinical observations
- Body measurements

### Condition
- Diagnoses
- Problems
- Health concerns
- Clinical status and verification status

### MedicationStatement
- Current medications
- Medication history
- Dosage instructions
- Active/inactive status

### AllergyIntolerance
- Allergies
- Intolerances
- Reactions
- Severity and criticality

### Immunization
- Vaccination records
- Vaccine products
- Administration dates
- Lot numbers

### DiagnosticReport
- Lab reports
- Imaging reports
- Pathology results
- Report status and conclusions

### DocumentReference
- Clinical documents
- Discharge summaries
- Progress notes
- Consent forms

## FHIR Version
DJ_Medi_Wallet_25 implements FHIR R4 (4.0.1) specifications.

## Data Format
All FHIR resources are stored in JSON format conforming to the FHIR specification.

## Example FHIR Patient Resource

```json
{
  "resourceType": "Patient",
  "id": "example-patient-001",
  "identifier": [
    {
      "system": "urn:oid:2.16.840.1.113883.2.4.6.3",
      "value": "738472983"
    }
  ],
  "name": [
    {
      "use": "official",
      "family": "Doe",
      "given": ["John", "Robert"]
    }
  ],
  "gender": "male",
  "birthDate": "1974-12-25",
  "address": [
    {
      "use": "home",
      "line": ["534 Erewhon St"],
      "city": "PleasantVille",
      "state": "Vic",
      "postalCode": "3999"
    }
  ]
}
```

## Example FHIR Observation Resource

```json
{
  "resourceType": "Observation",
  "id": "blood-pressure-001",
  "status": "final",
  "category": [
    {
      "coding": [
        {
          "system": "http://terminology.hl7.org/CodeSystem/observation-category",
          "code": "vital-signs",
          "display": "Vital Signs"
        }
      ]
    }
  ],
  "code": {
    "coding": [
      {
        "system": "http://loinc.org",
        "code": "85354-9",
        "display": "Blood pressure panel"
      }
    ]
  },
  "subject": {
    "reference": "Patient/example-patient-001"
  },
  "effectiveDateTime": "2023-11-14T09:30:00Z",
  "component": [
    {
      "code": {
        "coding": [
          {
            "system": "http://loinc.org",
            "code": "8480-6",
            "display": "Systolic blood pressure"
          }
        ]
      },
      "valueQuantity": {
        "value": 120,
        "unit": "mmHg",
        "system": "http://unitsofmeasure.org",
        "code": "mm[Hg]"
      }
    },
    {
      "code": {
        "coding": [
          {
            "system": "http://loinc.org",
            "code": "8462-4",
            "display": "Diastolic blood pressure"
          }
        ]
      },
      "valueQuantity": {
        "value": 80,
        "unit": "mmHg",
        "system": "http://unitsofmeasure.org",
        "code": "mm[Hg]"
      }
    }
  ]
}
```
