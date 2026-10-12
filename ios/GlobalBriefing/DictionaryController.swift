import UIKit

final class DictionaryController: UITableViewController, UISearchResultsUpdating {
    private let dictionary: OfflineDictionary
    private let search = UISearchController(searchResultsController: nil)
    private var results: [String]

    init(dictionary: OfflineDictionary) {
        self.dictionary = dictionary
        results = dictionary.search("")
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "오프라인 영한사전"
        search.searchResultsUpdater = self
        search.obscuresBackgroundDuringPresentation = false
        search.searchBar.placeholder = "영어 단어 또는 구문 검색"
        search.searchBar.autocapitalizationType = .none
        search.searchBar.autocorrectionType = .no
        navigationItem.searchController = search
        navigationItem.hidesSearchBarWhenScrolling = false
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "출처", style: .plain, target: self, action: #selector(showCredits))
        definesPresentationContext = true
        tableView.keyboardDismissMode = .onDrag
        let footer = UILabel(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 88))
        footer.numberOfLines = 0
        footer.textAlignment = .center
        footer.font = .preferredFont(forTextStyle: .footnote)
        footer.textColor = .secondaryLabel
        footer.text = "내장 표제어 \(dictionary.headwords.count.formatted())개 · 인터넷 없이 조회\n위키낱말사전 기여자 / Kaikki.org · CC BY-SA 4.0\n커뮤니티 사전이며 뜻풀이에 오류가 있을 수 있습니다."
        tableView.tableFooterView = footer
    }

    func updateSearchResults(for searchController: UISearchController) {
        results = dictionary.search(searchController.searchBar.text ?? "")
        tableView.reloadData()
        let empty = UILabel()
        empty.text = "내장 사전에 없는 단어입니다."
        empty.textAlignment = .center
        empty.textColor = .secondaryLabel
        tableView.backgroundView = results.isEmpty ? empty : nil
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { results.count }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "word") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "word")
        let word = results[indexPath.row]
        cell.textLabel?.text = word
        cell.detailTextLabel?.text = dictionary.words[word]?.joined(separator: " · ")
        cell.detailTextLabel?.numberOfLines = 3
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let word = results[indexPath.row]
        let detail = UIViewController()
        detail.title = word
        detail.view.backgroundColor = .systemBackground
        let text = UITextView()
        text.isEditable = false
        text.font = .preferredFont(forTextStyle: .body)
        text.text = (dictionary.words[word] ?? []).joined(separator: "\n\n")
            + "\n\n출처: 한국어 위키낱말사전 기여자 / Kaikki.org\nCC BY-SA 4.0\n원문 및 편집 이력: https://ko.wiktionary.org/wiki/"
            + (word.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? word)
        text.translatesAutoresizingMaskIntoConstraints = false
        detail.view.addSubview(text)
        NSLayoutConstraint.activate([
            text.topAnchor.constraint(equalTo: detail.view.safeAreaLayoutGuide.topAnchor),
            text.bottomAnchor.constraint(equalTo: detail.view.safeAreaLayoutGuide.bottomAnchor),
            text.leadingAnchor.constraint(equalTo: detail.view.leadingAnchor, constant: 16),
            text.trailingAnchor.constraint(equalTo: detail.view.trailingAnchor, constant: -16)
        ])
        navigationController?.pushViewController(detail, animated: true)
    }

    @objc private func showCredits() {
        let detail = UIViewController()
        detail.title = "사전 출처 및 라이선스"
        detail.view.backgroundColor = .systemBackground
        let text = UITextView()
        text.isEditable = false
        text.font = .preferredFont(forTextStyle: .body)
        if let url = Bundle.main.url(forResource: "DICTIONARY-NOTICE", withExtension: "txt") {
            text.text = try? String(contentsOf: url, encoding: .utf8)
        }
        text.translatesAutoresizingMaskIntoConstraints = false
        detail.view.addSubview(text)
        NSLayoutConstraint.activate([
            text.topAnchor.constraint(equalTo: detail.view.safeAreaLayoutGuide.topAnchor),
            text.bottomAnchor.constraint(equalTo: detail.view.safeAreaLayoutGuide.bottomAnchor),
            text.leadingAnchor.constraint(equalTo: detail.view.leadingAnchor, constant: 16),
            text.trailingAnchor.constraint(equalTo: detail.view.trailingAnchor, constant: -16)
        ])
        navigationController?.pushViewController(detail, animated: true)
    }
}
