# KeySwap macOS — Deferred Items

Items deferred during CEO review (2026-04-02). Not in MVP scope.

## P1 — Before Phase 1 Merge

- [ ] **Shifted-key mapping verification:** Verify Shift+number row (!, @, #, $, %, ^, &, *, (, )) and Shift+punctuation against the actual macOS "Hebrew" keyboard layout. Add verified mappings to TranslationContext's character table. Currently unshifted-only, unmapped chars pass through unchanged. Needs Mac hardware.

- [ ] **Verify IOHIDRequestAccess availability:** Test `IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)` on macOS. If this API doesn't work as expected (some sources indicate Input Monitoring is implicitly triggered by CGEventTap creation), redesign the PermissionsRouter onboarding flow to explain that the system dialog appears when the app first tries to monitor keys.

## P1 — Eng Review Design Changes

- [x] **Update stale documentation:** Fix 3 documents to match Design Doc (source of truth):
  - PRD: Change "NSPasteboardItem pointer" clipboard preservation to eager `dataForType:` copy
  - Architecture Doc: Change `NSEvent.addGlobalMonitorForEvents` to `CGEventTap`; update AppState enum to include PARTIAL and DEGRADED states; fix clipboard approach
  - Blueprint: Update clipboard approach, add Shift+F9, visual flash, About window, re-entrancy guard, DEGRADED state to testing section

## P2 — Post-MVP

- [ ] **Configurable hotkey:** Allow users to remap F9 to a different key via UserDefaults. Store preference in `UserDefaults.standard`. Add a Preferences window accessible from the menu bar. Default remains F9/Shift+F9.

- [ ] **Multi-language foundation:** Parameterize the language pair in TranslationContext so the engine can support additional layout pairs (e.g., Russian/English, Arabic/English) without rewriting core logic. Current implementation hardcodes English/Hebrew. Refactor the character mapping table to be injected rather than compiled-in.

## P3 — Nice to Have

- [ ] **Post-swap spell check:** After converting characters, run the translated output through `NSSpellChecker.shared()` to detect grammar/spelling errors introduced by the mapping (e.g., capitalization edge cases the rules miss). Either auto-correct or offer suggestions. Requires careful UX design to avoid surprising the user with unexpected changes.
