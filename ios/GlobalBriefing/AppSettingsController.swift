import UIKit

final class AppSettingsController: UITableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "설정 및 앱 정보"
    }

    override func numberOfSections(in tableView: UITableView) -> Int { 2 }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { section == 0 ? 1 : 2 }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        section == 0
            ? "온라인 조회를 켜면 내장 사전에 없는 영어 단어 또는 영어 뜻풀이가 Free Dictionary API 및 MyMemory로 전송됩니다. 자동 번역에는 오류가 있을 수 있습니다. 조회 결과와 단어장은 기기에 저장됩니다. 언제든 끌 수 있습니다."
            : "RSS 설명 기반의 영어 뉴스 읽기와 영한사전 학습 도구입니다. 실시간 속보나 전문 기사의 전체 요약을 보장하지 않습니다. 뉴스 출처와 발행·수집 시각은 각 기사에 표시됩니다."
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        if indexPath.section == 0 {
            cell.textLabel?.text = "온라인 단어 조회 허용"
            let toggle = UISwitch()
            toggle.isOn = UserDefaults.standard.bool(forKey: "onlineLookupAllowed")
            toggle.addTarget(self, action: #selector(changeOnlineLookup), for: .valueChanged)
            cell.accessoryView = toggle
            cell.selectionStyle = .none
        } else {
            cell.textLabel?.text = indexPath.row == 0 ? "개인정보 처리방침 · 지원" : "사전 출처 및 이용 조건"
            cell.accessoryType = .disclosureIndicator
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.section == 1 else { return }
        let detail = UIViewController()
        detail.title = indexPath.row == 0 ? "개인정보 · 지원" : "사전 출처"
        detail.view.backgroundColor = .systemBackground
        let text = UITextView()
        text.isEditable = false
        text.dataDetectorTypes = .link
        text.font = .preferredFont(forTextStyle: .body)
        text.adjustsFontForContentSizeCategory = true
        let name = indexPath.row == 0 ? "PRIVACY" : "DICTIONARY-NOTICE"
        if let url = Bundle.main.url(forResource: name, withExtension: "txt") {
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

    @objc private func changeOnlineLookup(_ sender: UISwitch) {
        UserDefaults.standard.set(sender.isOn, forKey: "onlineLookupAllowed")
    }
}
