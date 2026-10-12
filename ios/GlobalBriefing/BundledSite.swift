import WebKit

// Keep the existing reader UI in the app bundle; only news data is refreshed.
final class BundledSite: NSObject, WKURLSchemeHandler {
    private var tasks: [ObjectIdentifier: URLSessionDataTask] = [:]
    private let savedBriefing = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("latest-briefing.json")

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        let name = urlSchemeTask.request.url?.lastPathComponent ?? "index.html"
        guard ["index.html", "dictionary.json", "briefing.json", "globalbriefing.png", "privacy.html"].contains(name),
              let bundled = Bundle.main.url(forResource: name, withExtension: nil, subdirectory: "Web") else {
            urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist))
            return
        }
        if name != "briefing.json" {
            respond(urlSchemeTask, file: bundled, name: name)
            return
        }
        let id = ObjectIdentifier(urlSchemeTask)
        var request = URLRequest(url: URL(string: "https://outinletter.github.io/globalbriefing/briefing.json")!)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 8
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, _ in
            DispatchQueue.main.async {
                guard let self, self.tasks.removeValue(forKey: id) != nil else { return }
                if let data, (response as? HTTPURLResponse)?.statusCode == 200,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let sections = json["briefingSections"] as? [[String: Any]], !sections.isEmpty,
                   json["generatedAt"] is String {
                    try? data.write(to: self.savedBriefing, options: .atomic)
                    self.respond(urlSchemeTask, data: data, name: name)
                } else {
                    if let saved = try? Data(contentsOf: self.savedBriefing) {
                        self.respond(urlSchemeTask, data: saved, name: name)
                    } else {
                        self.respond(urlSchemeTask, file: bundled, name: name)
                    }
                }
            }
        }
        tasks[id] = task
        task.resume()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        tasks.removeValue(forKey: ObjectIdentifier(urlSchemeTask))?.cancel()
    }

    private func respond(_ task: WKURLSchemeTask, file: URL, name: String) {
        do { respond(task, data: try Data(contentsOf: file), name: name) }
        catch { task.didFailWithError(error) }
    }

    private func respond(_ task: WKURLSchemeTask, data: Data, name: String) {
        let mime = name.hasSuffix(".json") ? "application/json" : name.hasSuffix(".png") ? "image/png" : "text/html"
        task.didReceive(HTTPURLResponse(url: task.request.url!, statusCode: 200, httpVersion: "HTTP/1.1",
                                       headerFields: ["Content-Type": mime + "; charset=utf-8"])!)
        task.didReceive(data)
        task.didFinish()
    }
}
