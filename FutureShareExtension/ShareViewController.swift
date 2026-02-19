import UIKit
import SwiftUI
import FutureShared

class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        Task {
            let (url, title) = await extractSharedContent()

            let shareView = ShareView(
                url: url ?? "",
                title: title,
                onSend: { [weak self] item in
                    FutureStore.shared.add(item)
                    if !item.isNeverDeliver {
                        NotificationManager.shared.scheduleNotification(for: item)
                    }
                    self?.extensionContext?.completeRequest(returningItems: nil)
                },
                onCancel: { [weak self] in
                    self?.extensionContext?.cancelRequest(
                        withError: NSError(domain: "com.fsayed.Future", code: 0)
                    )
                }
            )

            let hosting = UIHostingController(rootView: shareView)
            addChild(hosting)
            view.addSubview(hosting.view)
            hosting.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
                hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            ])
            hosting.didMove(toParent: self)
        }
    }

    private func extractSharedContent() async -> (url: String?, title: String?) {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            return (nil, nil)
        }

        var extractedURL: String?
        var extractedTitle: String?

        for item in items {
            extractedTitle = item.attributedContentText?.string

            guard let attachments = item.attachments else { continue }

            for attachment in attachments {
                if attachment.hasItemConformingToTypeIdentifier("public.url") {
                    if let result = try? await attachment.loadItem(forTypeIdentifier: "public.url"),
                       let url = result as? URL {
                        extractedURL = url.absoluteString
                        break
                    }
                }

                if extractedURL == nil,
                   attachment.hasItemConformingToTypeIdentifier("public.plain-text") {
                    if let result = try? await attachment.loadItem(forTypeIdentifier: "public.plain-text"),
                       let text = result as? String {
                        if let url = URL(string: text), url.scheme?.hasPrefix("http") == true {
                            extractedURL = text
                        } else {
                            let detector = try? NSDataDetector(
                                types: NSTextCheckingResult.CheckingType.link.rawValue
                            )
                            let range = NSRange(text.startIndex..., in: text)
                            if let match = detector?.firstMatch(in: text, range: range),
                               let url = match.url {
                                extractedURL = url.absoluteString
                                if extractedTitle == nil {
                                    extractedTitle = text
                                }
                            }
                        }
                    }
                }
            }

            if extractedURL != nil { break }
        }

        return (extractedURL, extractedTitle)
    }
}
