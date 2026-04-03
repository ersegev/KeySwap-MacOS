# **Product Requirements Document: KeySwap (MVP)**

## **1\. Product Brief**

* **Product Name:** KeySwap  
* **Stage:** Minimum Viable Product (V1.0)  
* **Objective:** A lightweight macOS background utility designed to seamlessly correct bi-lingual (English \<-\> Hebrew) typing errors via a global hotkey, without destroying the user's clipboard history.  
* **Core Philosophy:** Silent, low-latency execution. Do not fight the OS; respect system limitations natively and push cognitive load to explicit user interactions only when strictly necessary.

## **2\. Target Audience & Jobs-to-be-Done (JTBD)**

* **Persona:** Fast-typing, bi-lingual Mac professionals (Developers, Writers, Communicators).  
* **JTBD:** *"When I realize I just typed a sentence in the wrong keyboard layout, I want to instantly translate those specific characters into the correct language without having to delete, switch layouts, and retype, so I can maintain my state of flow."*

## **3\. Core Features & Scope**

* **Global Trigger:** A system-wide hotkey listener bound to `F9` and `Shift+F9` (swap-back). Both trigger the identical swap pipeline; direction is determined by the current keyboard layout.  
* **Selection Logic:** \* *Primary:* Detect and swap actively highlighted text via macOS Accessibility APIs.  
  * *Fallback:* If no text is currently highlighted, the application will simulate the `Cmd + Shift + Left` keystroke macro to select the entire current line, and then execute the swap. Cursor placement relies strictly on native `Cmd + V` behavior (resting at the end of the pasted string).  
* **Translation Engine:** A bi-directional character mapping array translating English to Hebrew and vice versa, governed by the following strict capitalization state machine:  
  * *Constraint 0:* Auto-capitalization rules execute ONLY when the target output language is English.  
  * *Constraint 1 (Explicit Pass-Through):* Any `[A-Z]` character in the input string maps directly to `[A-Z]` in the output string.  
  * *Constraint 2 (Line Replacement):* `IF fallback_macro_used == TRUE` (line was selected automatically), `THEN output_string[0] = toUpper(output_string[0])`.  
  * *Constraint 3 (Punctuation Check):* Apply a Regex lookbehind on the translated string: `(?<=[\.\!\?]\s)[a-z]`. Convert any matching character to Uppercase. (Applies only to characters inside the selection).  
  * *Constraint 4 (Default):* All other characters default to lowercase English or standard Hebrew.  
* **Clipboard Preservation:** The application will eagerly read all `dataForType:` pairs from the current `NSPasteboardItem` array prior to execution, storing the type+data pairs in a local dictionary. After execution, the original clipboard contents are restored. Note: holding `NSPasteboardItem` object references alone does NOT survive `clearContents()` because the pasteboard server evicts backing data when cleared — eager data copy at stash time is required.  
* **Onboarding Flow:** A dedicated, single-window permission request UI requiring explicit user initialization to trigger macOS Accessibility and Input Monitoring system prompts.

## **4\. System Interactions & OS APIs**

* **Application State:** Runs as a background daemon (`LSUIElement = YES` in `Info.plist`).  
* **Boot Sequence:** Implements `SMAppService.mainApp.register()` to automatically add KeySwap to the user's macOS Login Items.  
* **UI Indicator:** Instantiates an `NSStatusItem` in the `NSStatusBar.system` with a functional `NSMenu`. Menu items vary by state:
  * ACTIVE: "KeySwap — Active" (disabled label), separator, "About KeySwap", "Quit KeySwap". Green icon flash for 0.5s on successful swap.
  * DEGRADED: "KeySwap — Degraded (retrying...)" (warning icon), separator, "About KeySwap", "Quit KeySwap".
  * PERMISSIONS_REQUIRED: Status indicator with option to open onboarding.
* **About Window:** Displays app version, hotkey reminder (F9 / Shift+F9), one-sentence description, and issue report link.
* **Re-entrancy Guard:** Boolean `isSwapping` flag with `defer` cleanup. 500ms SLA timeout cancels stuck swaps (no watchdog timer — see Engineering Design Doc for rationale).  
* **Input Monitoring:** Utilizes a `CGEventTap` at session level (`kCGSessionEventTap` + `kCGHeadInsertEventTap`) to detect and consume the `F9` / `Shift+F9` trigger. CGEventTap is used instead of `NSEvent.addGlobalMonitorForEvents` because it can consume events (preventing F9 from propagating to the active app).  
* **Text Manipulation:** \* Primary injection via `AXUIElement` (Accessibility API).  
  * Fallback injection via `CGEvent` (CoreGraphics synthetic `Cmd+V` keystrokes).  
* **System Feedback:** Auditory feedback mapped strictly to the system error sound (`NSSound.beep`) to indicate execution failure states.

## **5\. Edge Cases & Executable Mitigations**

1. **The Secure Input Blocker:** If `IsSecureEventInputEnabled()` returns true (e.g., focus is in a password field or locked terminal), the system aborts execution and triggers the auditory error sound.  
2. **The Paste Race Condition:** Requires asynchronous polling of `NSPasteboard`'s `changeCount`. The simulated `Cmd+V` keystroke is strictly blocked until the translated payload is mathematically verified in the clipboard server.  
3. **The Sandboxed App Drop:** The system attempts native `AXUIElement` text replacement first. If blocked by the target application's sandbox restrictions (e.g., Mac App Store or Electron apps), it falls back to a simulated `Cmd+V`.  
4. **Rich Media Clipboard Protection:** The application eagerly copies all type+data pairs from `NSPasteboardItem` objects via `dataForType:`. This is a transient memory spike (bounded by clipboard size) lasting < 500ms, after which stashed data is released. Holding `NSPasteboardItem` references alone is insufficient — the pasteboard server evicts backing data on `clearContents()`.  
5. **The Read-Only Field Trap:** The system must verify the target `AXUIElement` has a writable text attribute before executing the swap. If the field is read-only, execution aborts and triggers the auditory error sound.  
6. **The Massive Payload Limit:** Enforces a strict execution cap of 2,000 characters per swap. If the selected string exceeds this limit, execution aborts and triggers the auditory error sound.  
7. **The Undo (`Cmd + Z`) Corruption (Known Constraint):** The user's OS-level undo stack will be populated with our synthetic keystroke steps. Grouping these into a single native undo action requires a custom macOS IME, which is explicitly out of scope for V1.0.

## **6\. Success Metrics**

* **Execution Latency:** Trigger-to-replacement time consistently under 500ms.  
* **Data Integrity:** 0% failure rate for restoring complex clipboard items (`NSPasteboard` pointers).  
* **Onboarding Conversion:** \> 80% of users successfully grant both OS permissions via the gated UI flow.

