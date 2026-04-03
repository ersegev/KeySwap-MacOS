## **1\. Tech Stack & Visual Integration**

* **Core:** Swift 5+, native macOS AppKit, and ApplicationServices (specifically C-level CoreGraphics and Accessibility APIs).  
* **State Management:** Transient memory structures defined by the provided Data Contracts (ClipboardSnapshot, TranslationContext, ExecutionProfile, AppState).  
* **Visual Integration:** Since Leo has not provided a specific ui\_visual\_context or CSS tokens for this sprint, the Coder must utilize strictly native, un-styled AppKit/SwiftUI components for the Menu Bar indicator and the Permissions Onboarding window to maintain OS consistency.

## **2\. File Structure & Execution Steps**

**For the Coder:**

* **Info.plist**  
  * Explicitly set the LSUIElement key to YES to enforce the daemon behavior and hide the application from the Dock and Application Switcher. \[Maps to Syd: Epic 1\]  
* **Core/KeySwapApp.swift**
  * Implement the silent boot lifecycle.
  * Invoke SMAppService.mainApp.register() for Login Item registration. If registration fails, log error and continue (login item is a convenience, not a requirement).
  * Instantiate the NSStatusItem in the Menu Bar. Menu items vary by state: ACTIVE shows "KeySwap — Active" + About + Quit; DEGRADED shows warning icon + "KeySwap — Degraded (retrying...)" + About + Quit. \[Maps to Syd: User Story 3.6\]
  * Visual success flash: on successful swap, change NSStatusItem icon to green variant for 0.5s via `DispatchQueue.main.asyncAfter`.
* **UI/AboutWindow.swift**
  * Native NSWindow or SwiftUI sheet: app name + version, one-sentence description, hotkey reminder (F9 / Shift+F9), issue report link. Accessible from "About KeySwap" menu item.  
* **State/AppState.swift**
  * Implement discrete transition logging within the UI state container.
  * States: PERMISSIONS\_REQUIRED (neither granted), PARTIAL (one of two granted), ACTIVE (both granted), DEGRADED (CGEventTap failed/disabled by macOS).
  * Track specific state milestones: PERMISSIONS\_REQUIRED \-\> PARTIAL \-\> ACTIVE. ACTIVE \-\> DEGRADED on CGEventTap failure, with 30s retry loop for recovery (DEGRADED \-\> ACTIVE). \[Maps to Syd: User Story 6.1, Criteria 10\]
  * Expose a lightweight internal event dispatcher that records transition timestamps and drop-off points so Product can actively measure the \> 80% conversion SLA.
  * All state mutations must occur on the main thread to prevent UI desyncs in the Menu Bar.  
* **Security/PermissionsRouter.swift**  
  * Build the onboarding window to validate OS permissions.  
  * Explicitly use AXIsProcessTrusted() for Accessibility validation.  
  * Explicitly use IOHIDRequestAccess() for Input Monitoring validation. \[Maps to Syd: User Story 6.1\]  
* **Execution/GlobalHotkeyListener.swift**
  * Set up a C-level CGEventTap (`kCGSessionEventTap` + `kCGHeadInsertEventTap`) to detect and consume F9 (keyCode 100) and Shift+F9 (keyCode 100 + Shift modifier) keydown events. Both trigger the identical swap pipeline. \[Maps to Syd: User Story 1.1\]
  * Evaluate IsSecureEventInputEnabled() immediately upon hotkey trigger. If true, abort execution and trigger NSSound.beep(). \[Maps to Syd: User Story 2.1\]
  * Re-entrancy guard: `isSwapping` boolean with `defer { isSwapping = false }` cleanup. If `isSwapping == true` on entry, beep + abort.
  * 500ms SLA timeout: if swap pipeline exceeds 500ms, cancel pending polls, attempt clipboard restore, beep. Do NOT reset `isSwapping` (prevents concurrent clipboard corruption). See Engineering Design Doc for rationale.  
* **Engine/AccessibilityInteractor.swift**  
  * **Extraction:** Attempt to read kAXSelectedTextAttribute. If null, ping SyntheticEventGenerator to fire Cmd+Shift+Left, then retry. \[Maps to Syd: Epic 3\]  
  * **Injection & Sandbox Fallback:** Attempt to write the payload via kAXValueAttribute. If the OS returns kAXErrorNotImplemented or kAXErrorCannotComplete (Sandbox block), route the payload to ClipboardManager to stash the old clipboard, and instruct SyntheticEventGenerator to fire a synthetic Cmd+V. \[Maps to Syd: Criteria 3\]  
* **Execution/ExecutionProfile.swift**  
  * Validate that the target AXUIElement is writable and that the payload length is under 2,000 characters.  
  * If invalid, bypass translation and play an auditory error. \[Maps to Syd: User Story 4.1\]  
* **Engine/TranslationContext.swift**  
  * Implement the bi-directional English \<-\> Hebrew mapping logic.  
  * Rely purely on a statically compiled dictionary within the Swift binary.  
  * Isolate this class completely from AXUIElement logic or AppKit Undo stacks to ensure decoupling for the V3.0 Input Method Editor (IME). \[Maps to Syd: User Story 7.1\]  
* **Synthetic Event Generation** (eng review: merged into static utility / inline in consumers)
  * Generate the Cmd+Shift+Left synthetic keystroke for zero-selection extraction. \[Maps to Syd: User Story 3.5\]
  * Generate the Cmd+V synthetic keystroke for sandbox fallback injection.
  * If `CGEvent(keyboardEventSource:...)` returns nil, beep + abort.  
* **Memory/ClipboardManager.swift**
  * Implement LAZY clipboard stashing: only stash when AX direct write fails and Cmd+V fallback is triggered (not before AX write attempt).
  * Stash uses eager `dataForType:` copy for all declared types on each `NSPasteboardItem` — holding object references alone does NOT survive `clearContents()`.
  * ClipboardSnapshot is a nested struct inside ClipboardManager (eng review: class merge).
  * Poll NSPasteboard.general.changeCount using recursive `DispatchQueue.main.asyncAfter` (1ms interval, 50ms timeout) — no tight loops or sleep.
  * After Cmd+V, poll target kAXValueAttribute (10ms interval, 500ms timeout). If value changed, paste landed — restore clipboard. If timeout, paste failed — beep + restore clipboard.
  * Safely restore all type+data pairs to preserve rich media after injection. \[Maps to Syd: User Story 2.2\]

## **3\. Testing Strategy & Edge Cases**

**For the Unit Tester:**

* **Latency Benchmark:** Write an XCTest performance suite asserting that the entire execution pipeline (keydown to Cmd+V fallback) strictly completes in under 500ms.
* **Sandbox Simulation:** Mock a sandboxed text field that returns kAXErrorCannotComplete upon a write request. Assert that the AccessibilityInteractor catches the error, performs LAZY clipboard stash (eager `dataForType:` copy), writes the payload to the NSPasteboard, and triggers the Cmd+V event without dropping data.
* **Zero-Selection Loop:** Test the edge case where Cmd+Shift+Left highlights a space or a newline instead of a word. Ensure the system beeps and aborts rather than entering an infinite loop.
* **Rich Media Restoration:** Validate that copying a 50MB TIFF image to the clipboard, triggering KeySwap (Cmd+V fallback path), and pasting afterward perfectly retains the image data via eager type+data pair restoration.
* **Hard-Block Verification:** Mock an active password field constraint and assert that the translation engine completely bypasses execution.
* **Funnel State Tracking:** Write tests asserting that AppState correctly logs a "drop-off" event if the user closes the Permissions Router without granting both OS-level requirements.
* **Re-entrancy Guard:** Assert that rapid double-tap F9 (second press while `isSwapping == true`) results in beep + abort for the second press.
* **SLA Timeout:** Assert that a swap exceeding 500ms triggers cancellation, clipboard restore (best-effort), and beep. Verify `isSwapping` is NOT reset by the timeout (only by `defer`).
* **Failed Paste Detection:** Mock kAXValueAttribute not changing after Cmd+V. Assert beep is emitted and clipboard is restored.
* **DEGRADED State:** Assert CGEventTap failure transitions AppState to DEGRADED. Assert 30s retry loop recovers to ACTIVE on success.
* **Shift+F9 Trigger:** Assert Shift+F9 triggers the identical swap pipeline as F9.
* **Visual Flash:** Assert NSStatusItem icon changes to green variant on successful swap and reverts after 0.5s.
* **About Window:** Assert version, hotkey reminder, description, and issue link render correctly.

**For the full test plan (56 test cases):** See `Documents/KeySwap Engineering Design Doc.md` and the test plan artifact.

## **4\. Security & Review Standards**

**For the Code Reviewer:**

* **Memory Leaks:** Reject any Pull Request that holds `NSPasteboardItem` references across `clearContents()` instead of eagerly copying via `dataForType:`. The resting memory must remain strictly under 30MB (transient spikes during clipboard stash are acceptable).  
* **Concurrency Guardrails:** Ensure that when the sandbox fallback is triggered, the Cmd+V keystroke is not dispatched until the ClipboardManager confirms the new payload has been fully registered via NSPasteboard.general.changeCount. A race condition here will paste old data.  
* **Privacy & Telemetry Guardrails:** Verify that the conversion tracking hooks only record boolean state transitions and time deltas, strictly ensuring no personally identifiable information (PII) or keystrokes are accidentally ingested into the analytics buffer.  
* **Network Isolation:** Verify that the TranslationContext lookup mechanism avoids any network calls or dynamic module loading.  
* **State Mutation:** Ensure AppState enum mutations are strictly handled on the main thread to prevent UI desyncs in the Menu Bar.

