nick-vermeulen: Review this application which generates QR codes for the FHIR data packets.  Generate a prompt that will regenerate the application including the compression of QR codes in another rust based application. 

GitHub Copilot: Read [](file:///Users/nickvermeulen/Documents/Current_Documents/Programming/1_Production_iOS_Apps/TuariFHIRDataReceiver/Code/src/lib/qr.ts)

Read [](file:///Users/nickvermeulen/Documents/Current_Documents/Programming/1_Production_iOS_Apps/TuariFHIRDataReceiver/Code/src/lib/encoding.ts)

Read [](file:///Users/nickvermeulen/Documents/Current_Documents/Programming/1_Production_iOS_Apps/TuariFHIRDataReceiver/Code/src/lib/fhir.ts)

Read [](file:///Users/nickvermeulen/Documents/Current_Documents/Programming/1_Production_iOS_Apps/TuariFHIRDataReceiver/Code/src/components/QrGeneratorPage.tsx)

Read [](file:///Users/nickvermeulen/Documents/Current_Documents/Programming/1_Production_iOS_Apps/TuariFHIRDataReceiver/Code/src/components/SingleObservationQR.tsx)

Read [](file:///Users/nickvermeulen/Documents/Current_Documents/Programming/1_Production_iOS_Apps/TuariFHIRDataReceiver/Code/src/components/MultiExamQR.tsx)

Read [](file:///Users/nickvermeulen/Documents/Current_Documents/Programming/1_Production_iOS_Apps/TuariFHIRDataReceiver/Code/src/components/StandardReportBuilder.tsx)

Read [](file:///Users/nickvermeulen/Documents/Current_Documents/Programming/1_Production_iOS_Apps/TuariFHIRDataReceiver/Code/src/components/SnomedSelect.tsx)

Read [](file:///Users/nickvermeulen/Documents/Current_Documents/Programming/1_Production_iOS_Apps/TuariFHIRDataReceiver/Code/src/lib/snomed.ts)

Read [](file:///Users/nickvermeulen/Documents/Current_Documents/Programming/1_Production_iOS_Apps/TuariFHIRDataReceiver/Code/src/lib/reports.ts)

Read [](file:///Users/nickvermeulen/Documents/Current_Documents/Programming/1_Production_iOS_Apps/TuariFHIRDataReceiver/Code/src/lib/terminology.ts)

Read [](file:///Users/nickvermeulen/Documents/Current_Documents/Programming/1_Production_iOS_Apps/TuariFHIRDataReceiver/Code/src/services/FhirService.ts)

Read [](file:///Users/nickvermeulen/Documents/Current_Documents/Programming/1_Production_iOS_Apps/TuariFHIRDataReceiver/Code/src/App.tsx)

Read [](file:///Users/nickvermeulen/Documents/Current_Documents/Programming/1_Production_iOS_Apps/TuariFHIRDataReceiver/Code/src-tauri/src/main.rs#1-1), lines 1 to 400

Searched text for `snomed_import_csv` (`**/src-tauri/src/**/*.rs`), 2 results

Read [](file:///Users/nickvermeulen/Documents/Current_Documents/Programming/1_Production_iOS_Apps/TuariFHIRDataReceiver/Code/src-tauri/src/main.rs#600-600), lines 600 to 880

Searched text for `gzip` (`**/src-tauri/src/**/*.rs`), no results

Read [](file:///Users/nickvermeulen/Documents/Current_Documents/Programming/1_Production_iOS_Apps/TuariFHIRDataReceiver/Code/README.md)

**App Overview**
- React + MUI frontend inside a Tauri shell (main.rs) orchestrates BLE, Wi‑Fi upload server, Downloads watcher, and SQLite-backed SNOMED/report templates; commands exposed via `tauri::command` glue the UI and backend.
- QR creation flows live in SingleObservationQR.tsx, MultiExamQR.tsx, and StandardReportBuilder.tsx, each building FHIR `Observation`/`DiagnosticReport`/`Bundle` objects with helpers from fhir.ts.
- Payloads are serialized and, when longer than 2 kB, gzipped with `pako.gzip` and base64-prefixed (`compressed:`) through encoding.ts; QR bitmaps are produced with the `qrcode` package (qr.ts) at EC level “M”.
- SNOMED search/import is handled by the Rust backend (`snomed_import_csv`, `snomed_search`) and surfaced through the `SnomedSelect` autocomplete (SnomedSelect.tsx); report templates follow a similar invoke-based pattern via reports.ts.
- Tauri emits domain events (`fhir-received`, `templates-updated`, etc.) that drive navigation and data refresh (App.tsx), and auxiliary screens cover scanning, conversion, sending, and settings.

**Prompt**
```
You are an expert Rust developer. Build a Rust-centric desktop application that replicates the functionality of the existing “PDR App – Tauri POC,” focusing on generating QR codes for FHIR payloads with automatic compression.

High-level requirements:
• Use a Rust-first stack (e.g., Tauri + Rust/Leptos, or pure Rust GUI) while keeping the UI desktop-friendly. Recreate three QR workflows: single observation, multi-observation exam, and template-driven standard reports.
• Provide forms that let users select SNOMED CT concepts from a locally managed SQLite database. Include CSV import commands that upsert rows (concept_id, term, category) and expose search/category/count APIs.
• Build FHIR resources in Rust mirroring the TypeScript versions: `Observation`, `DiagnosticReport`, and collection `Bundle`. Support numeric, yes/no, and text values plus template-derived fields.
• Serialize payloads to JSON, then apply gzip compression when the JSON exceeds ~2000 characters. Prefix compressed payloads with `compressed:` and base64-encode the gzipped bytes. Leave shorter payloads as plain JSON.
• Generate QR codes from the final payload strings. Use an appropriate Rust crate (e.g., `qrcode` + `image` or `qrcode-generator`) and match the original settings: error-correction level M, scale ≈6, margin ≈2. Display or save the QR bitmap and surface the raw payload for copy/export.
• Recreate ancillary features that matter to QR generation: SNOMED autocomplete UI, exam presets, validation (e.g., NHS number check), and template imports for reports (SQL/JSON) with rust-side commands to load them into SQLite.
• Ensure the code is modular: separate modules for database layer, FHIR models/builders, encoding/compression utilities, and UI. Add comments where logic is non-obvious.
• Provide build/run instructions (cargo commands) and list dependencies (e.g., `tauri`, `tokio`, `rusqlite`, `serde`, `flate2`/`miniz_oxide`, `base64`, `qrcode`).

Deliverables:
1. Cargo workspace (or project) with Rust source implementing the described features.
2. SQLite schema migrations/creation code.
3. UI code that allows users to generate and preview QR codes across the three workflows.
4. Tests or sample payloads demonstrating gzip compression and QR generation.
5. README summarizing setup, SNOMED import, and QR generation steps.
```