import UIKit
import WebKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = UINavigationController(rootViewController: BriefingController())
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
}

final class BriefingController: UIViewController, WKNavigationDelegate, WKScriptMessageHandler {
    private let home = URL(string: "https://outinletter.github.io/globalbriefing/")!
    private let readerURL = URL(string: "briefing://app/index.html")!
    private let webView: WKWebView = {
        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(BundledSite(), forURLScheme: "briefing")
        return WKWebView(frame: .zero, configuration: config)
    }()
    private let dictionary = try? OfflineDictionary()
    private var lookupTask: Task<Void, Never>?
    private var onlineMeanings = UserDefaults.standard.dictionary(forKey: "onlineMeanings.v1") as? [String: String] ?? [:]
    private var selectedWord: (word: String, meaning: String)?

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = ""
        navigationItem.largeTitleDisplayMode = .never
        navigationController?.navigationBar.prefersLargeTitles = false
        view.backgroundColor = .systemBackground
        webView.navigationDelegate = self
        let script = """
        document.documentElement.classList.add('native-app');
        document.addEventListener('click', function(event) {
          if (event.target.closest && event.target.closest('#settingsBtn') && location.protocol === 'briefing:') {
            event.preventDefault();
            event.stopImmediatePropagation();
            window.webkit.messageHandlers.dictionaryLookup.postMessage('__settings__');
            return;
          }
          const word = event.target.closest && event.target.closest('.lookup-word');
          if (!word || location.protocol !== 'briefing:') return;
          event.preventDefault();
          event.stopImmediatePropagation();
          window.webkit.messageHandlers.dictionaryLookup.postMessage(word.dataset.word);
        }, true);
        """
        webView.configuration.userContentController.addUserScript(
            WKUserScript(source: script, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        webView.configuration.userContentController.add(WeakDictionaryHandler(self), name: "dictionaryLookup")
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        let refresh = UIRefreshControl()
        refresh.addTarget(self, action: #selector(reload), for: .valueChanged)
        webView.scrollView.refreshControl = refresh
        webView.load(URLRequest(url: readerURL))
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    private func openSettingsMenu() {
        let menu = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        menu.addAction(UIAlertAction(title: "글자 · 읽기 설정", style: .default) { [weak self] _ in
            self?.webView.evaluateJavaScript("document.getElementById('settingsPanel').classList.add('is-open')")
        })
        menu.addAction(UIAlertAction(title: "현재 단어 저장", style: .default) { [weak self] _ in self?.saveWord() })
        menu.addAction(UIAlertAction(title: "내 단어장", style: .default) { [weak self] _ in
            self?.navigationController?.pushViewController(VocabularyController(style: .insetGrouped), animated: true)
        })
        menu.addAction(UIAlertAction(title: "뉴스 새로고침", style: .default) { [weak self] _ in self?.reload() })
        menu.addAction(UIAlertAction(title: "공유", style: .default) { [weak self] _ in self?.share() })
        menu.addAction(UIAlertAction(title: "설정 · 개인정보 · 지원", style: .default) { [weak self] _ in
            self?.navigationController?.pushViewController(AppSettingsController(style: .insetGrouped), animated: true)
        })
        menu.addAction(UIAlertAction(title: "취소", style: .cancel))
        menu.popoverPresentationController?.sourceView = webView
        menu.popoverPresentationController?.sourceRect = CGRect(x: webView.bounds.maxX - 30, y: 24, width: 1, height: 1)
        present(menu, animated: true)
    }

    @objc private func reload() {
        webView.load(URLRequest(url: readerURL, cachePolicy: .reloadIgnoringLocalCacheData))
    }

    @objc private func share() {
        let sheet = UIActivityViewController(activityItems: [home], applicationActivities: nil)
        sheet.popoverPresentationController?.sourceView = webView
        sheet.popoverPresentationController?.sourceRect = CGRect(x: webView.bounds.midX, y: webView.bounds.midY, width: 1, height: 1)
        present(sheet, animated: true)
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame,
              message.frameInfo.securityOrigin.host == "app",
              let word = message.body as? String, word.count <= 100,
              presentedViewController == nil else { return }
        if word == "__settings__" {
            openSettingsMenu()
            return
        }
        let result = dictionary?.lookup(word)
        lookupTask?.cancel()
        selectedWord = nil
        if let result {
            let meaning = result.meanings.prefix(2).joined(separator: " · ")
            selectedWord = (result.word, meaning)
            displayMeaning("\(result.word): \(meaning)")
            return
        }
        let key = dictionary?.normalize(word) ?? word.lowercased()
        if let cached = onlineMeanings[key] {
            selectedWord = (key, cached)
            displayMeaning("\(word): \(cached)")
            return
        }
        guard UserDefaults.standard.bool(forKey: "onlineLookupAllowed") else {
            displayMeaning("\(word): 내장 사전에 없습니다. 설정에서 온라인 조회를 허용할 수 있습니다.")
            return
        }
        displayMeaning("\(word): 온라인에서 뜻을 조회하는 중...")
        lookupTask = Task { [weak self] in
            do {
                let meaning = try await OnlineMeaning.lookup(key)
                guard !Task.isCancelled, let self else { return }
                guard UserDefaults.standard.bool(forKey: "onlineLookupAllowed") else {
                    self.displayMeaning("온라인 조회가 꺼져 있습니다.")
                    return
                }
                self.onlineMeanings[key] = meaning
                UserDefaults.standard.set(self.onlineMeanings, forKey: "onlineMeanings.v1")
                self.selectedWord = (key, meaning)
                self.displayMeaning("\(word): \(meaning)")
            } catch {
                guard !Task.isCancelled, let self else { return }
                let message = (error as? OnlineMeaning.Failure)?.localizedDescription
                    ?? "온라인 조회 실패. 인터넷 연결을 확인하세요."
                self.displayMeaning("\(word): \(message)")
            }
        }
    }

    private func displayMeaning(_ meaning: String) {
        let text = String(meaning.prefix(220))
        webView.callAsyncJavaScript("""
            const text = document.getElementById('dictionaryText');
            if (text) text.textContent = meaning;
            const actions = document.getElementById('dictActions');
            if (actions) actions.style.display = 'none';
            """, arguments: ["meaning": text], in: nil, in: .page, completionHandler: nil)
    }

    private func saveWord() {
        guard let selectedWord else {
            displayMeaning("뜻을 조회한 단어를 먼저 선택하세요.")
            return
        }
        var saved = UserDefaults.standard.dictionary(forKey: "savedVocabulary.v1") as? [String: String] ?? [:]
        saved[selectedWord.word] = selectedWord.meaning
        UserDefaults.standard.set(saved, forKey: "savedVocabulary.v1")
        displayMeaning("저장됨 · \(selectedWord.word): \(selectedWord.meaning)")
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }
        if url.scheme == "briefing", url.host == "app", navigationAction.targetFrame != nil {
            decisionHandler(.allow)
        } else {
            if ["https", "http"].contains(url.scheme ?? "") {
                UIApplication.shared.open(url)
            }
            decisionHandler(.cancel)
        }
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.scrollView.refreshControl?.endRefreshing()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        showFailure(error)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        showFailure(error)
    }

    private func showFailure(_ error: Error) {
        webView.scrollView.refreshControl?.endRefreshing()
        guard (error as NSError).code != NSURLErrorCancelled else { return }
        let alert = UIAlertController(title: "브리핑을 불러올 수 없습니다",
                                      message: "인터넷 연결을 확인하고 다시 시도하세요.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "다시 시도", style: .default) { [weak self] _ in self?.reload() })
        alert.addAction(UIAlertAction(title: "닫기", style: .cancel))
        present(alert, animated: true)
    }
}

private final class WeakDictionaryHandler: NSObject, WKScriptMessageHandler {
    private weak var target: WKScriptMessageHandler?
    init(_ target: WKScriptMessageHandler) { self.target = target }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(userContentController, didReceive: message)
    }
}
