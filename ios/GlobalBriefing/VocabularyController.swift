import UIKit

final class VocabularyController: UITableViewController {
    private var words = UserDefaults.standard.dictionary(forKey: "savedVocabulary.v1") as? [String: String] ?? [:]
    private var keys: [String] { words.keys.sorted() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "내 단어장"
        navigationItem.rightBarButtonItem = editButtonItem
        refreshEmptyState()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { words.count }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        let word = keys[indexPath.row]
        cell.textLabel?.text = word
        cell.textLabel?.font = .preferredFont(forTextStyle: .headline)
        cell.textLabel?.adjustsFontForContentSizeCategory = true
        cell.detailTextLabel?.text = words[word]
        cell.detailTextLabel?.font = .preferredFont(forTextStyle: .body)
        cell.detailTextLabel?.adjustsFontForContentSizeCategory = true
        cell.detailTextLabel?.numberOfLines = 0
        cell.selectionStyle = .none
        return cell
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else { return }
        words.removeValue(forKey: keys[indexPath.row])
        UserDefaults.standard.set(words, forKey: "savedVocabulary.v1")
        tableView.deleteRows(at: [indexPath], with: .automatic)
        refreshEmptyState()
    }

    private func refreshEmptyState() {
        let label = UILabel()
        label.text = "기사에서 단어를 누른 뒤\n메뉴의 ‘현재 단어 저장’을 선택하세요.\n저장한 단어는 오프라인에서 복습할 수 있습니다."
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = .preferredFont(forTextStyle: .body)
        tableView.backgroundView = words.isEmpty ? label : nil
    }
}
