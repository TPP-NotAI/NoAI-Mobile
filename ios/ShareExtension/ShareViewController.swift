import UIKit
import Social
import MobileCoreServices
import Photos

class ShareViewController: SLComposeServiceViewController {

  private let appGroupId    = "group.com.rooverse.app"
  private let urlScheme     = "ShareMedia"  // matches receive_sharing_intent default
  private let userDefaults  : UserDefaults?

  required init?(coder: NSCoder) {
    userDefaults = UserDefaults(suiteName: appGroupId)
    super.init(coder: coder)
  }

  override func isContentValid() -> Bool { true }

  override func didSelectPost() {
    guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
      done(); return
    }

    let dispatchGroup = DispatchGroup()
    var sharedItems: [[String: Any]] = []
    var errorMessages: [String] = []

    for item in items {
      for provider in (item.attachments ?? []) {

        // ── Plain text / URL ─────────────────────────────────────────
        if provider.hasItemConformingToTypeIdentifier(kUTTypeURL as String) {
          dispatchGroup.enter()
          provider.loadItem(forTypeIdentifier: kUTTypeURL as String, options: nil) { data, error in
            defer { dispatchGroup.leave() }
            if let url = data as? URL {
              sharedItems.append(["type": "text", "value": url.absoluteString])
            } else if let error = error {
              errorMessages.append(error.localizedDescription)
            }
          }
        } else if provider.hasItemConformingToTypeIdentifier(kUTTypePlainText as String) {
          dispatchGroup.enter()
          provider.loadItem(forTypeIdentifier: kUTTypePlainText as String, options: nil) { data, error in
            defer { dispatchGroup.leave() }
            if let text = data as? String {
              sharedItems.append(["type": "text", "value": text])
            } else if let error = error {
              errorMessages.append(error.localizedDescription)
            }
          }

        // ── Image ────────────────────────────────────────────────────
        } else if provider.hasItemConformingToTypeIdentifier(kUTTypeImage as String) {
          dispatchGroup.enter()
          provider.loadItem(forTypeIdentifier: kUTTypeImage as String, options: nil) { data, error in
            defer { dispatchGroup.leave() }
            if let image = data as? UIImage,
               let imageData = image.jpegData(compressionQuality: 0.9) {
              let fileName = "\(UUID().uuidString).jpg"
              if let url = self.saveToAppGroup(data: imageData, fileName: fileName) {
                sharedItems.append(["type": "image", "value": url.absoluteString])
              }
            } else if let url = data as? URL {
              sharedItems.append(["type": "image", "value": url.absoluteString])
            } else if let error = error {
              errorMessages.append(error.localizedDescription)
            }
          }

        // ── Video ────────────────────────────────────────────────────
        } else if provider.hasItemConformingToTypeIdentifier(kUTTypeMovie as String) {
          dispatchGroup.enter()
          provider.loadItem(forTypeIdentifier: kUTTypeMovie as String, options: nil) { data, error in
            defer { dispatchGroup.leave() }
            if let url = data as? URL {
              // Copy to app group container so main app can access it
              if let dest = self.copyToAppGroup(from: url, ext: "mp4") {
                sharedItems.append(["type": "video", "value": dest.absoluteString])
              } else {
                sharedItems.append(["type": "video", "value": url.absoluteString])
              }
            } else if let error = error {
              errorMessages.append(error.localizedDescription)
            }
          }
        }
      }
    }

    dispatchGroup.notify(queue: .main) {
      self.userDefaults?.set(sharedItems, forKey: "sharedMedia")
      self.userDefaults?.synchronize()
      // Open main app via custom URL scheme
      let url = URL(string: "\(self.urlScheme)://dataUrl")!
      _ = self.openURL(url)
      self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
  }

  // MARK: - Helpers

  private func saveToAppGroup(data: Data, fileName: String) -> URL? {
    guard let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else { return nil }
    let url = container.appendingPathComponent(fileName)
    try? data.write(to: url)
    return url
  }

  private func copyToAppGroup(from source: URL, ext: String) -> URL? {
    guard let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else { return nil }
    let dest = container.appendingPathComponent("\(UUID().uuidString).\(ext)")
    try? FileManager.default.copyItem(at: source, to: dest)
    return dest
  }

  @discardableResult
  private func openURL(_ url: URL) -> Bool {
    var responder: UIResponder? = self
    while responder != nil {
      if let application = responder as? UIApplication {
        return application.perform(#selector(UIApplication.open(_:options:completionHandler:)),
                                   with: url,
                                   with: [:]) != nil
      }
      responder = responder?.next
    }
    return false
  }

  private func done() {
    extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
  }

  override func configurationItems() -> [Any]! { [] }
}
