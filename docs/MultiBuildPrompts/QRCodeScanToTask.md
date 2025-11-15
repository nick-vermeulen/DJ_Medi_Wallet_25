**Prompt Plan**

1. **Tab Visibility Logic**
   - Prompt: update `ContentView` so it adds a “Capture” tab only when `AppLockManager.userProfile?.role == .practitioner`, wiring the new view with required environment objects.

2. **QR Capture Feature**
   - Prompt: scaffold `CaptureTaskView` (SwiftUI) that launches a QR scanner (reuse `QRScannerView`), parses the SD-JWT payload, and surfaces the decoded reason/request metadata.

3. **Task Form UI**
   - Prompt: extend `CaptureTaskView` with fields for NHS number (validated modulus-11), patient location (CoreLocation picker/manual entry), request type picker, and reason prefilled from QR result (read-only).

4. **Supabase Task Creation**
   - Prompt: add async API on `SupabaseService`/`WalletManager` to `createTask` with captured fields + QR metadata; call it from the view’s “Send” action with loading/error states.

5. **Navigation & Feedback**
   - Prompt: ensure successful submission dismisses the form and shows confirmation/toast; handle errors gracefully and log for diagnostics.

6. **Tests & Docs**
   - Prompt: add unit tests for QR parsing → task model mapping, NHS validation, and a README section describing the practitioner capture workflow.