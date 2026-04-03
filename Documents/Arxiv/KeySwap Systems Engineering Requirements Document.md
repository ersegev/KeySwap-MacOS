# **KeySwap: Systems Engineering Requirements Document**

## **1\. System Overview Brief**

KeySwap is a highly optimized, native macOS background daemon designed to seamlessly correct bilingual typing errors with sub-500ms latency. Leveraging direct OS-level accessibility frameworks and C-level CoreGraphics integration, the system safely stashes clipboard state, securely swaps text, and enforces strict memory and privacy boundaries without ever relying on external network calls.

## **2\. Epics**

* **Epic 1: System Monitoring & Authorization** \[Traceability: Global Hotkey Listener, Permissions Router, AppState\]  
* **Epic 2: Secure State & Clipboard Preservation** \[Traceability: Clipboard Manager, ClipboardSnapshot\]  
* **Epic 3: Text Extraction & Injection Pipeline** \[Traceability: Accessibility Interactor, Synthetic Event Generator\]  
* **Epic 4: Native Translation & Execution Guardrails** \[Traceability: TranslationContext, ExecutionProfile\]  
* **Epic 5: Application Lifecycle & UI State** \[Traceability: Login Item Registrar, Menu Bar Indicator\]  
* **Epic 6: Permissions Onboarding & Funnel Metrics** \[Traceability: Permissions Router\]  
* **Epic 7: Scalability & IME Decoupling** \[Traceability: Scalability & Evolution\]

## **3\. User Stories**

**Core Execution & Monitoring**

* **User Story 1.1:** *As a bilingual macOS user*, I want the system to silently detect when I press the F9 key so that my mistyped text can be instantly captured and corrected without breaking my workflow.  
* **User Story 3.5 (Zero-Selection):** *As a fast typist*, I want the system to automatically select the word I just typed if I hit F9 without explicitly highlighting anything, so that my typing flow remains completely uninterrupted.

**Security, Memory & Guardrails**

* **User Story 2.1:** *As a privacy-conscious user*, I want the utility to automatically detect and halt if I am typing in a secure password field so that my sensitive credentials are never read or leaked.  
* **User Story 2.2:** *As a user who frequently copies rich media*, I want my clipboard state to be restored flawlessly via memory pointers so that using the text-swap feature doesn't erase my previously copied images, files, or complex formats.  
* **User Story 4.1:** *As a power user*, I want the app to alert me with an auditory error if I try to translate a massive block of text (over 2,000 characters) so that the system doesn't freeze or consume excessive memory.

**Lifecycle & Onboarding**

* **User Story 3.6 (Silent Boot):** *As an everyday user*, I want KeySwap to automatically launch quietly on system startup and live in my Menu Bar so that I can easily check its status, grant permissions, or quit the app if needed.  
* **User Story 6.1 (Onboarding):** *As a new user*, I want a secure, native macOS onboarding window that clearly guides me through granting system permissions so that I understand exactly why the utility needs them to function.

**Architecture & Evolution**

* **User Story 7.1 (Decoupling):** *As a system engineer*, I want the TranslationContext class to be fundamentally decoupled from the AppKit and Accessibility layers so that the translation logic can be cleanly migrated to a native Input Method Editor (IME) in V3.0.

## **4\. Data Contracts**

Since KeySwap is stateless and relies on transient memory, the following contract defines the core internal state schema required during the execution lifecycle:

JSON

{  
  "ClipboardSnapshot": {  
    "previousChangeCount": "Int",  
    "items": "Array\<NSPasteboardItem\>"  
  },  
  "TranslationContext": {  
    "rawInput": "String",  
    "fallbackMacroUsed": "Boolean",  
    "isTargetEnglish": "Boolean",  
    "translatedOutput": "String"  
  },  
  "ExecutionProfile": {  
    "targetElement": "AXUIElement",  
    "isWritable": "Boolean",  
    "characterCount": "Int"  
  },  
  "AppState": {  
    "isAccessibilityGranted": "Boolean",  
    "isInputMonitoringGranted": "Boolean",  
    "engineStatus": "Enum(ACTIVE, PAUSED, PERMISSIONS\_REQUIRED)"  
  }  
}

## **5\. Acceptance Criteria**

**Criteria 1: Latency SLA & Execution Speed**

* **Given** a valid, highlighted text selection in a writable application.  
* **When** the global F9 hotkey is pressed.  
* **Then** the full end-to-end execution (from keydown to text injection) must strictly execute in \< 500ms.

**Criteria 2: Secure Input Hard-Block**

* **Given** IsSecureEventInputEnabled() evaluates to true (e.g., a password field is active).  
* **When** the F9 hotkey is triggered.  
* **Then** the system must abort the translation process immediately.  
* **And** play an auditory error via NSSound.beep().

**Criteria 3: Sandboxed App Fallback & Clipboard Restoration**

* **Given** an active OS sandbox restriction blocking direct AXUIElement writes.  
* **When** KeySwap falls back to a simulated Cmd+V injection.  
* **Then** the ClipboardManager must asynchronously poll NSPasteboard.general.changeCount.  
* **And** successfully restore the original NSPasteboardItem pointers after the payload is written.

**Criteria 4: Payload & Writable State Guardrails**

* **Given** the target text field is read-only OR the highlighted selection exceeds 2,000 characters.  
* **When** KeySwap builds the ExecutionProfile.  
* **Then** the system must bypass the translation engine entirely.  
* **And** play an auditory error without modifying the system pasteboard.

**Criteria 5: Zero-Selection Synthetic Fallback**

* **Given** the F9 hotkey is pressed securely.  
* **When** the AXUIElement attempts to read kAXSelectedTextAttribute and returns a null or empty string.  
* **Then** the Synthetic Event Generator must immediately post a Cmd+Shift+Left keystroke.  
* **And** the system must loop back to the text extraction phase to capture the newly highlighted text.

**Criteria 6: Boot Registration & Menu Bar Lifecycle**

* **Given** the application is installed and run for the first time.  
* **When** SMAppService.mainApp.register() is invoked.  
* **Then** the daemon must register as a macOS Login Item.  
* **And** an NSStatusItem must immediately appear in the Menu Bar displaying the current AppState.engineStatus with an option to quit.

**Criteria 7: NFR \- Resting Memory Constraint**

* **Given** the background daemon is running in an idle state.  
* **When** monitored via macOS Activity Monitor or Instruments.  
* **Then** the resting memory footprint must strictly remain under \< 30MB.  
* **And** clipboard caching must never duplicate raw public.data.

**Criteria 8: V1.0 Translation Architecture**

* **Given** the system is executing the TranslationContext payload for English \<-\> Hebrew.  
* **When** mapping the characters.  
* **Then** the lookup mechanism must rely purely on a statically compiled array/dictionary within the Swift binary.  
* **And** strictly avoid any dynamic loading, network calls, or database abstractions.

**Criteria 9: LSUIElement (Daemon) Enforcement**

* **Given** KeySwap is actively running on the user's system.  
* **When** a user views their Dock or the Application Switcher (Cmd+Tab).  
* **Then** the KeySwap icon must strictly remain hidden.  
* **And** the application's Info.plist must explicitly set LSUIElement to YES.

**Criteria 10: Onboarding API & Conversion Guardrails**

* **Given** an unverified user is proceeding through the initial setup flow.  
* **When** KeySwap prompts for necessary OS system permissions.  
* **Then** the onboarding window must specifically rely on AXIsProcessTrusted() for validating Accessibility and IOHIDRequestAccess() for Input Monitoring.  
* **And** the UI state container (AppState) must support the tracking required to hit the product requirement of a \> 80% conversion success metric.

**Criteria 11: Decoupling for V2.0/V3.0 Evolution**

* **Given** the Dev team is implementing the V1.0 TranslationContext.  
* **When** writing the bi-directional mapping engine (English \<-\> Hebrew).  
* **Then** the code must be strictly isolated from any AXUIElement read/write execution logic.  
* **And** it must not rely on the macOS Undo stack, guaranteeing that the subsystem can be ported directly over to a custom macOS Input Method Editor (IME) architecture in the future without refactoring.

