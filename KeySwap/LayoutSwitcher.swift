import Foundation
import Carbon

// MARK: - LayoutSwitcher
//
// Detects whether the active keyboard layout is Hebrew or English,
// and switches the layout after a successful swap.
//
// Direction detection uses TISCopyCurrentKeyboardInputSource() — unambiguous vs.
// the Unicode-range heuristic that was replaced (see Design Doc resolved decisions).

final class LayoutSwitcher {

    enum Direction {
        case hebrewToEnglish  // active layout is Hebrew → swap to English
        case englishToHebrew  // active layout is English (or other) → swap to Hebrew
    }

    // MARK: - Detection

    /// Returns the swap direction based on the current keyboard layout.
    func swapDirection() -> Direction {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let idPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID),
              let id = Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String? else {
            // Default to English→Hebrew if we can't determine the layout
            return .englishToHebrew
        }

        #if DEBUG
        print("[LayoutSwitcher] swapDirection: current layout = \(id)")
        #endif
        return id.contains("Hebrew") ? .hebrewToEnglish : .englishToHebrew
    }

    // MARK: - Switching

    /// Switches the keyboard layout to `target` after a successful swap.
    /// Logs a warning on failure but does not abort (swap already succeeded).
    func switchLayout(to direction: Direction) {
        // Try multiple IDs — "ABC" is the modern macOS English layout,
        // "US" is the legacy name. Hebrew may also have variants.
        let targetIDs: [String]
        switch direction {
        case .hebrewToEnglish:
            targetIDs = ["com.apple.keylayout.ABC", "com.apple.keylayout.US"]
        case .englishToHebrew:
            targetIDs = ["com.apple.keylayout.Hebrew"]
        }

        #if DEBUG
        print("[LayoutSwitcher] switchLayout direction=\(direction), targetIDs=\(targetIDs)")
        #endif

        // Filter to only keyboard layouts that can be selected.
        let filter = [
            kTISPropertyInputSourceCategory: kTISCategoryKeyboardInputSource,
            kTISPropertyInputSourceIsSelectCapable: true,
        ] as CFDictionary

        guard let sources = TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource] else {
            #if DEBUG
            print("[LayoutSwitcher] ✗ TISCreateInputSourceList returned nil")
            #endif
            return
        }

        #if DEBUG
        let ids = sources.compactMap { src -> String? in
            guard let ptr = TISGetInputSourceProperty(src, kTISPropertyInputSourceID) else { return nil }
            return Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
        }
        print("[LayoutSwitcher] Installed selectable layouts: \(ids)")
        #endif

        // Try each target ID in priority order
        for targetID in targetIDs {
            for source in sources {
                guard let idPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID),
                      let id = Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String?,
                      id == targetID else {
                    continue
                }

                let err = TISSelectInputSource(source)
                #if DEBUG
                print("[LayoutSwitcher] TISSelectInputSource(\(targetID)) → err=\(err)")
                #endif
                return
            }
        }

        // Exact match not found — try partial match (e.g. "Hebrew-QWERTY" variants)
        for source in sources {
            guard let idPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID),
                  let id = Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String? else {
                continue
            }

            let matches: Bool
            switch direction {
            case .hebrewToEnglish:
                matches = !id.contains("Hebrew")
                    && id.hasPrefix("com.apple.keylayout.")
            case .englishToHebrew:
                matches = id.contains("Hebrew")
            }

            if matches {
                let err = TISSelectInputSource(source)
                #if DEBUG
                print("[LayoutSwitcher] Fuzzy match: TISSelectInputSource(\(id)) → err=\(err)")
                #endif
                return
            }
        }

        #if DEBUG
        print("[LayoutSwitcher] ✗ No matching layout found for direction \(direction)")
        #endif
    }
}
