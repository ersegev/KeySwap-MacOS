import Foundation

// MARK: - CorrectionProvider

/// Protocol covering both range-finding and word correction.
/// Keeps NSSpellChecker (AppKit) entirely in the app layer — this package never imports AppKit.
public protocol CorrectionProvider {
    /// Returns the NSRange of the first misspelled word in `text` starting at `offset`.
    /// NSRange.length == 0 means no misspelling found from that offset.
    func misspelledRange(in text: String, startingAt offset: Int) -> NSRange

    /// Returns the top correction for `word`, or nil if no correction is available.
    func correction(forWord word: String, in text: String) -> String?
}

// MARK: - SpellCheckFilter

public struct SpellCheckFilter {

    public init() {}

    /// Corrects misspelled words in `text` using the given provider.
    /// Only runs for `.english` target — Hebrew output is returned unchanged.
    /// Returns the corrected string, or the original if no corrections are needed.
    public func postProcess(_ text: String, language: TargetLanguage, provider: CorrectionProvider) -> String {
        guard language == .english else { return text }
        guard !text.isEmpty else { return text }

        // Phase 1: Collect all misspelled ranges from the original string.
        var ranges: [NSRange] = []
        var offset = 0
        while offset < text.utf16.count {
            let range = provider.misspelledRange(in: text, startingAt: offset)
            guard range.length > 0 else { break }
            let nextOffset = range.location + range.length
            guard nextOffset > offset else { break } // infinite-loop guard: provider must advance
            ranges.append(range)
            offset = nextOffset
        }

        guard !ranges.isEmpty else { return text }

        // Phase 2: Apply corrections back-to-front so earlier NSRange positions
        // are unaffected by variable-length replacements.
        var result = text
        for range in ranges.sorted(by: { $0.location > $1.location }) {
            guard range.location + range.length <= result.utf16.count else { continue }
            let word = (result as NSString).substring(with: range)
            if let correction = provider.correction(forWord: word, in: result) {
                result = (result as NSString).replacingCharacters(in: range, with: correction)
            }
        }

        return result
    }
}
