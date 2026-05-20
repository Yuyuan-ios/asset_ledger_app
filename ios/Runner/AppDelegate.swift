import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private static let shareChannelName = "com.yuyuan.assetledger/share_inbox"

  private var pendingShareFiles: [[String: String]] = []
  private var shareChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    registerShareChannel()

    if let url = launchOptions?[.url] as? URL {
      _ = handleIncomingShareFile(url: url)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if handleIncomingShareFile(url: url) {
      return true
    }
    return super.application(app, open: url, options: options)
  }

  private func registerShareChannel() {
    guard let registrar = registrar(forPlugin: "AssetLedgerShareInboxPlugin") else {
      return
    }
    let channel = FlutterMethodChannel(
      name: AppDelegate.shareChannelName,
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterError(code: "unavailable", message: "AppDelegate released", details: nil))
        return
      }
      switch call.method {
      case "consumePending":
        result(self.takeNextPendingShareFile())
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    shareChannel = channel
  }

  private func handleIncomingShareFile(url: URL) -> Bool {
    guard url.isFileURL else { return false }
    let needsScope = url.startAccessingSecurityScopedResource()
    defer {
      if needsScope { url.stopAccessingSecurityScopedResource() }
    }
    guard let content = try? String(contentsOf: url, encoding: .utf8) else {
      return false
    }
    let payload: [String: String] = [
      "content": content,
      "name": url.lastPathComponent,
    ]
    pendingShareFiles.append(payload)
    return true
  }

  private func takeNextPendingShareFile() -> [String: String]? {
    guard !pendingShareFiles.isEmpty else { return nil }
    return pendingShareFiles.removeFirst()
  }
}
