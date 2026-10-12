import Foundation

struct OfflineDictionary {
    private struct Payload: Decodable {
        let words: [String: [String]]
        let forms: [String: String]
    }
    let words: [String: [String]]
    let headwords: [String]
    private let forms: [String: String]

    init(url: URL? = Bundle.main.url(forResource: "offline-dictionary", withExtension: "json")) throws {
        guard let url else { throw CocoaError(.fileNoSuchFile) }
        let payload = try JSONDecoder().decode(Payload.self, from: Data(contentsOf: url))
        words = payload.words
        forms = payload.forms
        headwords = words.keys.sorted()
    }

    func normalize(_ text: String) -> String {
        text.lowercased().replacingOccurrences(of: "’", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
    }

    func lookup(_ text: String) -> (word: String, meanings: [String])? {
        let key = normalize(text)
        var candidates = [key]
        if let base = forms[key] { candidates.append(base) }
        if key.hasSuffix("'s") { candidates.append(String(key.dropLast(2))) }
        for (suffix, replacement) in [("ies", "y"), ("ied", "y"), ("es", ""), ("s", ""),
                                      ("ed", ""), ("ed", "e"), ("ing", ""), ("ing", "e")] {
            if key.hasSuffix(suffix), key.count > suffix.count + 1 {
                let stem = String(key.dropLast(suffix.count))
                candidates.append(stem + replacement)
                if replacement.isEmpty, stem.count > 2, stem.last == stem.dropLast().last {
                    candidates.append(String(stem.dropLast()))
                }
            }
        }
        for candidate in candidates {
            if let meanings = words[candidate] { return (candidate, meanings) }
        }
        return nil
    }

    func search(_ text: String) -> [String] {
        let key = normalize(text)
        guard !key.isEmpty else { return Array(headwords.prefix(100)) }
        var result = lookup(key).map { [$0.word] } ?? []
        for word in headwords where word.hasPrefix(key) && !result.contains(word) {
            result.append(word)
            if result.count >= 100 { break }
        }
        return result
    }
}
