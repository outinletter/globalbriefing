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
    private let webView = WKWebView()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let dictionary = try? OfflineDictionary()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "GlobalBriefing"
        view.backgroundColor = .systemBackground
        webView.navigationDelegate = self
        let script = """
        document.addEventListener('click', function(event) {
          const word = event.target.closest && event.target.closest('.lookup-word');
          if (!word || location.origin !== 'https://outinletter.github.io') return;
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
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: spinner)
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(share)),
            UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(reload)),
            UIBarButtonItem(title: "영한사전", style: .plain, target: self, action: #selector(openDictionary))
        ]
        webView.load(URLRequest(url: home))
    }

    @objc private func reload() {
        webView.load(URLRequest(url: home, cachePolicy: .reloadIgnoringLocalCacheData))
    }

    @objc private func share() {
        let sheet = UIActivityViewController(activityItems: [home], applicationActivities: nil)
        sheet.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItems?.first
        present(sheet, animated: true)
    }

    @objc private func openDictionary() {
        guard let dictionary else {
            let alert = UIAlertController(title: "사전 오류", message: "내장 사전을 불러오지 못했습니다.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "닫기", style: .cancel))
            present(alert, animated: true)
            return
        }
        navigationController?.pushViewController(DictionaryController(dictionary: dictionary), animated: true)
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame,
              message.frameInfo.securityOrigin.host == home.host,
              let word = message.body as? String, word.count <= 100,
              presentedViewController == nil else { return }
        let result = dictionary?.lookup(word)
        let meanings = result?.meanings.prefix(2).joined(separator: " · ")
            ?? "내장 사전에 없는 단어입니다."
        let text = String("\(result?.word ?? word): \(meanings)".prefix(220))
        webView.callAsyncJavaScript("""
            const text = document.getElementById('dictionaryText');
            if (text) text.textContent = meaning;
            const actions = document.getElementById('dictActions');
            if (actions) actions.style.display = 'none';
            """, arguments: ["meaning": text], in: nil, in: .page, completionHandler: nil)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }
        if url.scheme == "https", url.host == home.host,
           url.path.hasPrefix(home.path), navigationAction.targetFrame != nil {
            decisionHandler(.allow)
        } else {
            if ["https", "http"].contains(url.scheme ?? "") {
                UIApplication.shared.open(url)
            }
            decisionHandler(.cancel)
        }
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        spinner.startAnimating()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        spinner.stopAnimating()
        webView.scrollView.refreshControl?.endRefreshing()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        showFailure(error)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        showFailure(error)
    }

    private func showFailure(_ error: Error) {
        spinner.stopAnimating()
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
