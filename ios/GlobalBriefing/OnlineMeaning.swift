import Foundation

enum OnlineMeaning {
    private struct Entry: Decodable {
        struct Meaning: Decodable {
            struct Definition: Decodable { let definition: String }
            let definitions: [Definition]
        }
        let meanings: [Meaning]
    }

    private struct Translation: Decodable {
        struct Response: Decodable { let translatedText: String }
        let responseData: Response
        let responseStatus: Int
        let quotaFinished: Bool?
    }

    enum Failure: LocalizedError {
        case missing, quota
        var errorDescription: String? {
            switch self {
            case .missing: return "온라인에서도 한국어 뜻을 찾지 못했습니다."
            case .quota: return "온라인 조회 한도에 도달했습니다. 나중에 다시 시도하세요."
            }
        }
    }

    static func lookup(_ word: String) async throws -> String {
        guard !word.isEmpty, word.utf8.count <= 100 else { throw Failure.missing }
        var url = URLComponents(string: "https://api.dictionaryapi.dev")!
        url.path = "/api/v2/entries/en/" + word
        var request = URLRequest(url: url.url!)
        request.timeoutInterval = 5
        let dictionaryResponse = try? await URLSession.shared.data(for: request)
        var input = word
        var label = "온라인 번역"
        if let (data, response) = dictionaryResponse,
           (response as? HTTPURLResponse)?.statusCode == 200,
           let entries = try? JSONDecoder().decode([Entry].self, from: data) {
            if let definition = entries.first?.meanings.first?.definitions.first?.definition,
               !definition.isEmpty, definition.utf8.count <= 400 {
                input = definition
                label = "온라인 뜻풀이·자동 번역"
            }
        }
        try Task.checkCancellation()
        var translationURL = URLComponents(string: "https://api.mymemory.translated.net/get")!
        translationURL.queryItems = [URLQueryItem(name: "q", value: input),
                                    URLQueryItem(name: "langpair", value: "en|ko")]
        var translationRequest = URLRequest(url: translationURL.url!)
        translationRequest.timeoutInterval = 10
        let (translatedData, translatedResponse) = try await URLSession.shared.data(for: translationRequest)
        guard (translatedResponse as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let result = try JSONDecoder().decode(Translation.self, from: translatedData)
        if result.quotaFinished == true || result.responseStatus == 429 { throw Failure.quota }
        let meaning = result.responseData.translatedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard result.responseStatus == 200, meaning.range(of: "[가-힣]", options: .regularExpression) != nil else {
            throw Failure.missing
        }
        return "[\(label) · MyMemory] \(meaning)"
    }
}
