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



You are an expert Swift developer. Build a Swift-based desktop/mobile application (macOS Catalyst or universal iOS/iPadOS) that replicates the functionality of the “PDR App – Tauri POC,” focusing on generating QR codes for FHIR payloads with automatic compression, and remaining payload-compatible with the Rust implementation.

High-level requirements:
• Use SwiftUI (preferred) with Combine/async-await where appropriate. Provide three QR workflows: single observation, multi-observation exam, and template-driven standard reports. Keep the UI desktop-friendly and responsive.
• Manage SNOMED CT concepts in a local SQLite database (use GRDB or SQLite.swift). Implement CSV import that upserts rows (concept_id, term, category) and expose search/category/count services for the UI pickers.
• Recreate the FHIR data models (`Observation`, `DiagnosticReport`, `Bundle`) in Swift structs/classes. Support numeric, yes/no, and text values and map template-driven elements to FHIR entries using Codable for JSON.
• Serialize payloads to JSON strings. When the JSON exceeds ~2000 characters, gzip-compress the UTF-8 bytes, base64-encode them, and prefix the final string with `compressed:`. Shorter payloads remain plain JSON. Compression and prefixing must be byte-perfect compatible with the Rust version.
• Generate QR codes from the final payload strings using a Swift QR library (e.g., CoreImage’s CIFilter, SwiftQRCodeGenerator) with error-correction level M, scale ≈6, margin ≈2. Render previews in the UI and expose the raw payload for copying/sharing. Support exporting QR images and payload text.
• Include SNOMED autocomplete controls, exam presets, validation logic (including NHS number modulus-11 check), and report template importers for SQL/JSON files to populate SQLite.
• Architect modules cleanly: separate layers for database access, FHIR builders, encoding/compression utilities, and presentation. Add concise comments for non-obvious logic and surface Combine/async patterns clearly.
• Provide interoperability hooks: document how the Swift app reads QR payloads emitted by the Rust app and vice versa, including decoding compressed payloads and constructing FHIR objects.
• Supply build/run instructions (Xcode scheme, minimum OS targets), dependency setup (Swift Package Manager packages), and entitlement/config notes for file imports if targeting iOS/macOS sandboxing.

Deliverables:
1. Swift project/workspace implementing the described features (SwiftUI + App lifecycle).
2. SQLite schema creation/migration code and import utilities for SNOMED/report templates.
3. UI implementing the three QR-generation flows with previews and payload export.
4. Unit/UI tests or sample fixtures demonstrating gzip compression/decompression parity and QR generation.
5. README covering setup, SNOMED/template import steps, and QR interoperability with the Rust app.


You are an expert Node.js developer. Build a TypeScript-based Node + React (or Electron) application that replicates the “PDR App – Tauri POC,” focusing on generating QR codes for FHIR payloads with automatic compression, while staying payload-compatible with the Rust and Swift implementations.

High-level requirements:
• Use a Node.js stack with TypeScript. Acceptable UIs: web (React + Vite), Electron, or Next.js desktop shell. Implement the three QR workflows—single observation, multi-observation exam, and template-driven standard reports—in a desktop-friendly interface.
• Manage SNOMED CT concepts via SQLite (use better-sqlite3, knex, or Prisma). Provide CLI/GUI CSV import that upserts rows (concept_id, term, category) and expose REST/IPC/search endpoints for autocomplete, categories, and counts.
• Recreate FHIR builders in TypeScript mirroring the original app: `Observation`, `DiagnosticReport`, and `Bundle` types. Support numeric, yes/no, and text values plus template-driven inputs; ensure JSON output conforms to FHIR expectations.
• Serialize payloads and, for JSON strings exceeding ~2000 chars, gzip-compress the UTF-8 bytes, base64-encode them, and prefix the payload with `compressed:`. Shorter payloads must remain plain JSON. Ensure compression logic matches the Rust/Swift implementations byte-for-byte (e.g., use `zlib.gzipSync` with deterministic options).
• Generate QR codes from payload strings using a Node-friendly library (`qrcode`, `qrcode-generator`, or `qrcode-terminal` for previews). Match settings: error-correction level M, module scale ≈6, margin ≈2. Render QR previews in the UI and expose raw payloads for copy/export. Support saving PNG/SVG outputs.
• Include SNOMED autocomplete controls, exam presets, validation rules (including the NHS number modulus-11 check), and report template importers for SQL/JSON files that populate SQLite tables. Surface template CRUD APIs similar to `report_standards`, `report_types`, and `report_elements`.
• Structure the project cleanly: separate packages/modules for database access, FHIR builders, encoding/compression utilities, QR generation, and UI. Add concise documentation/comments for non-obvious logic. If Electron is used, ensure secure IPC patterns.
• Provide interoperability documentation: demonstrate that this Node app can decode QR payloads produced by the Rust and Swift apps (handling the `compressed:` prefix) and produce payloads consumable by them.
• Supply setup instructions (`npm install`, `npm run dev/build`), configuration for SQLite migrations, and tests (Jest/Vitest) or sample fixtures proving gzip parity and QR generation.

Deliverables:
1. Monorepo/project with Node/TypeScript source, including UI and backend layers.
2. SQLite schema/migration scripts plus SNOMED/report template import utilities.
3. UI components covering all three QR-generation flows with previews and payload exports.
4. Automated tests or sample scripts verifying compression/decompression compatibility and QR generation.
5. README summarizing setup, SNOMED/template import steps, and QR interoperability across platforms.