## **1\. System Context & Overview**

The North Star for KeySwap is absolute minimalism: a silent, low-latency macOS background utility that corrects bilingual typing errors without disrupting the user's flow or destroying their clipboard history. Given the requirements for deep OS-level integration, latency under 500ms, and strict memory management regarding the clipboard, this architecture relies entirely on native macOS frameworks (AppKit, ApplicationServices, Accessibility).

KeySwap will operate as a background daemon (LSUIElement), utilizing a global keyboard monitor to trap the F9 trigger. It orchestrates a secure interaction between the system pasteboard and native UI element accessibility attributes to achieve the text swap natively, falling back to simulated keystrokes only when restricted by the OS sandbox.

Code snippet

flowchart TD

    A\[Global Hotkey F9\] \--\> B{Secure Input Enabled?}

    B \-- Yes \--\> C\[Play Error Sound & Abort\]

    B \-- No \--\> D{Text Highlighted?}

    

    D \-- Yes \--\> E\[AXUIElement Read Text\]

    D \-- No \--\> F\[Simulate Cmd+Shift+Left\]

    F \--\> E

    

    E \--\> G{Read-Only Field or \>2000 Chars?}

    G \-- Yes \--\> C

    G \-- No \--\> H\[Capture NSPasteboardItem Pointers\]

    

    H \--\> I\[Execute Translation Engine\]

    I \--\> J{Sandbox/AXUI Write Blocked?}

    

    J \-- No \--\> K\[AXUIElement Inject Text\]

    J \-- Yes \--\> L\[Write Payload to Pasteboard\]

    L \--\> M\[Poll Pasteboard changeCount\]

    M \--\> N\[Simulate Cmd+V\]

    

    K \--\> O\[Restore Original NSPasteboard Pointers\]

    N \--\> O

## **2\. Core Architecture & NFRs**

**The Architecture:** Native Swift Application (AppKit) with C-Level CoreGraphics/Accessibility Integration.

This approach provides the deepest possible OS integration, ensuring execution latency sits well under the 500ms threshold with a negligible resting memory footprint. By leveraging direct, pointer-level access to NSPasteboard, we can stash clipboard memory safely without copying raw data, fully satisfying the constraints around preserving rich media.

**Non-Functional Requirements (NFRs):**

* **NFR \- Execution Latency:** End-to-end execution (from F9 keydown to text injection) must strictly execute in \< 500ms.  
* **NFR \- Memory Footprint:** Resting memory consumption must not exceed 30MB. Clipboard stashing uses eager `dataForType:` copy of all type+data pairs from `NSPasteboardItem` objects (holding object references alone does NOT survive `clearContents()`). This causes a transient memory spike during swap (bounded by clipboard size, lasting < 500ms), after which stashed data is released.  
* **NFR \- Security/Permissions:** The app must explicitly verify IsSecureEventInputEnabled() before executing to prevent leaking passwords. It relies strictly on local macOS permissions (Accessibility & Input Monitoring) with zero external network calls.  
* **NFR \- Resilience:** The translation payload execution must gracefully abort and trigger an auditory error if the selection payload exceeds 2,000 characters or targets a read-only field.

## **3\. Core Data Models**

Since KeySwap is a local, stateless background utility, state is transient and held strictly in memory during the execution lifecycle. No persistent database is required.

* **ClipboardSnapshot** \[Maps to PRD: 3\. Core Features \- Clipboard Preservation / 5\. Edge Cases \- Rich Media Clipboard Protection\]
  * Fields: previousChangeCount (Int), items (Array of Dictionary\<String, Data\> — eagerly copied type+data pairs).
  * Purpose: Captures the system clipboard state via eager `dataForType:` copy and restores it after execution. Nested struct inside ClipboardManager (eng review: class merge).  
* **TranslationContext** \[Maps to PRD: 3\. Core Features \- Translation Engine\]  
  * Fields: rawInput (String), fallbackMacroUsed (Boolean), isTargetEnglish (Boolean), translatedOutput (String).  
  * Purpose: Manages the state machine for the auto-capitalization and punctuation regex rules.  
* **ExecutionProfile** \[Maps to PRD: 5\. Edge Cases \- Massive Payload Limit & Read-Only Field Trap\]  
  * Fields: targetElement (AXUIElement), isWritable (Boolean), characterCount (Int).  
  * Purpose: Validates if the operation is safe to proceed before initiating the clipboard wipe.  
* **AppState** \[Maps to PRD: 4\. System Interactions \- UI Indicator & Onboarding Flow\]
  * Fields: isAccessibilityGranted (Boolean), isInputMonitoringGranted (Boolean), engineStatus (Enum: ACTIVE, PARTIAL, PERMISSIONS\_REQUIRED, DEGRADED).
  * Purpose: A reactive state container (observable) that drives both the Menu Bar indicator and the gating logic of the Onboarding Window. States: PERMISSIONS\_REQUIRED (neither granted), PARTIAL (one of two granted), ACTIVE (both granted), DEGRADED (CGEventTap failed or disabled by macOS — 30s retry loop attempts recovery).

## **4\. Key Interfaces & Protocols**

KeySwap's interfaces are strict, native bindings to the macOS kernel and window server.

* **Global Hotkey Listener:** \[Maps to PRD: 4\. System Interactions \- Input Monitoring\]
  * Interface: CGEventTap at session level (`kCGSessionEventTap` + `kCGHeadInsertEventTap`) filtering for keyCode 100 (F9) and keyCode 100 + Shift modifier (Shift+F9). CGEventTap is used instead of NSEvent.addGlobalMonitorForEvents because it can consume events, preventing F9 from propagating to the active app. Includes `isSwapping` re-entrancy guard with `defer` cleanup and 500ms SLA timeout.  
* **Accessibility Interactor:** \[Maps to PRD: 4\. System Interactions \- Text Manipulation & 5\. Edge Cases \- The Sandboxed App Drop\]  
  * Interface: AXUIElementCopyAttributeValue (to read kAXSelectedTextAttribute) and AXUIElementSetAttributeValue (to overwrite text).  
* **Synthetic Event Generator:** \[Maps to PRD: 3\. Core Features \- Selection Logic\]  
  * Interface: CGEvent(keyboardEventSource: virtualKey, key: keyCode, keyDown: true) coupled with CGEvent.post(tap: .cghidEventTap). Used for Cmd+Shift+Left and Cmd+V.  
* **Clipboard Manager:** \[Maps to PRD: 5\. Edge Cases \- The Paste Race Condition\]
  * Interface: NSPasteboard.general.changeCount. Polling uses recursive `DispatchQueue.main.asyncAfter` scheduling (1ms interval, 50ms timeout) instead of tight loops to avoid CPU spin. Clipboard stashing is LAZY — only performed when AX direct write fails and Cmd+V fallback is triggered. Stash eagerly copies all type+data pairs via `dataForType:` (not pointer retention). ClipboardSnapshot is a nested struct inside ClipboardManager (eng review: class merge).  
* **Login Item Registrar:** \[Maps to PRD: 4\. System Interactions \- Boot Sequence\]  
  * Interface: SMAppService.mainApp.register().  
* **Menu Bar Indicator:** \[Maps to PRD: 4\. System Interactions \- UI Indicator\]  
  * Interface: NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength) coupled with an NSMenu to display state and provide a quit toggle.  
* **Permissions Router:** \[Maps to PRD: 3\. Core Features \- Onboarding Flow\]  
  * Interface: AXIsProcessTrusted() (Accessibility) and IOHIDRequestAccess() (Input Monitoring). Used strictly within the Onboarding Window to validate the \> 80% conversion success metric.  
* **Auditory Feedback:** \[Maps to PRD: 4\. System Interactions \- System Feedback\]  
  * Interface: NSSound.beep(). Triggered strictly by the ExecutionProfile abort conditions (e.g., Secure Input blocked, payload \> 2,000 characters).

## **5\. Scalability & Evolution**

For V1.0, the bi-directional mapping (English \<-\> Hebrew) will be a statically compiled dictionary/array in Swift for maximum lookup speed, avoiding complex database abstractions or dynamic loading to preserve the latency constraint.

Because the TranslationContext class is fundamentally decoupled from the OS-level Accessibility Interactor, the system is highly evolvable. Adding new language maps (e.g., Arabic, Russian) in V2.0 will not require touching the core OS interaction logic. Furthermore, if V3.0 demands we solve the OS Undo stack limitation by transitioning to a custom macOS Input Method Editor (IME), the core clipboard management and translation engine subsystems can be ported over intact without requiring a total rewrite of the application's foundation.

