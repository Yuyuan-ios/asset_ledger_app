import Flutter
import Security
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private static let shareChannelName = "com.yuyuan.assetledger/share_inbox"
  private static let subscriptionIdentityChannelName = "com.yuyuan.assetledger/subscription_identity"
  private static let appAccountTokenKey = "subscription.appAccountToken"

  private var pendingShareFiles: [[String: String]] = []
  private var shareChannel: FlutterMethodChannel?
  private var subscriptionIdentityChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    registerShareChannel()
    registerSubscriptionIdentityChannel()

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

  private func registerSubscriptionIdentityChannel() {
    guard let registrar = registrar(forPlugin: "AssetLedgerSubscriptionIdentityPlugin") else {
      return
    }
    let channel = FlutterMethodChannel(
      name: AppDelegate.subscriptionIdentityChannelName,
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "getAppAccountToken":
        result(Self.keychainString(for: Self.appAccountTokenKey))
      case "setAppAccountToken":
        guard let token = call.arguments as? String, !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
          result(FlutterError(code: "invalid_token", message: "appAccountToken is required", details: nil))
          return
        }
        do {
          try Self.setKeychainString(token.trimmingCharacters(in: .whitespacesAndNewlines), for: Self.appAccountTokenKey)
          result(nil)
        } catch {
          result(FlutterError(code: "keychain_write_failed", message: "Could not store appAccountToken", details: nil))
        }
      case "deleteAppAccountToken":
        Self.deleteKeychainString(for: Self.appAccountTokenKey)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    subscriptionIdentityChannel = channel
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

  private static func keychainString(for key: String) -> String? {
    var query = keychainQuery(for: key)
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne

    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    guard status == errSecSuccess, let data = item as? Data else {
      return nil
    }
    return String(data: data, encoding: .utf8)
  }

  private static func setKeychainString(_ value: String, for key: String) throws {
    let data = Data(value.utf8)
    var query = keychainQuery(for: key)
    let update = [kSecValueData as String: data]
    let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
    if status == errSecSuccess {
      return
    }
    if status != errSecItemNotFound {
      throw KeychainError.unhandled(status)
    }

    query[kSecValueData as String] = data
    query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
    let addStatus = SecItemAdd(query as CFDictionary, nil)
    guard addStatus == errSecSuccess else {
      throw KeychainError.unhandled(addStatus)
    }
  }

  private static func deleteKeychainString(for key: String) {
    SecItemDelete(keychainQuery(for: key) as CFDictionary)
  }

  private static func keychainQuery(for key: String) -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: Bundle.main.bundleIdentifier ?? "com.yuyuan.assetledger",
      kSecAttrAccount as String: key,
    ]
  }
}

private enum KeychainError: Error {
  case unhandled(OSStatus)
}
