import Flutter
import UIKit

public class SecureStoragePlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "nexus.secure_storage", binaryMessenger: registrar.messenger())
    let instance = SecureStoragePlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "storeIdentity":
      if let args = call.arguments as? [String: Any], let blob = args["blob"] as? FlutterStandardTypedData {
        let data = blob.data
        let ok = storeIdentity(data: data)
        result(ok)
      } else {
        result(false)
      }
    case "importIdentity":
      if let args = call.arguments as? [String: Any], let blob = args["blob"] as? FlutterStandardTypedData {
        let data = blob.data
        let ok = storeIdentity(data: data)
        result(ok)
      } else {
        result(false)
      }
    case "wipeDevice":
      let ok = wipeIdentity()
      result(ok)
    case "getIdentityBiometric":
      if let data = getIdentityWithBiometrics() {
        result(FlutterStandardTypedData(bytes: data))
      } else {
        result(nil)
      }
    case "storeMetadata":
      if let args = call.arguments as? [String: Any], let json = args["json"] as? String {
        let ok = storeMetadata(json: json)
        result(ok)
      } else {
        result(false)
      }
    case "getMetadata":
      if let json = getMetadata() {
        result(json)
      } else {
        result(nil)
      }
    case "storeIdentityBiometric":
      if let args = call.arguments as? [String: Any], let blob = args["blob"] as? FlutterStandardTypedData {
        let data = blob.data
        let ok = storeIdentityWithBiometrics(data: data)
        result(ok)
      } else {
        result(false)
      }
    case "importIdentityBiometric":
      if let args = call.arguments as? [String: Any], let blob = args["blob"] as? FlutterStandardTypedData {
        let data = blob.data
        let ok = storeIdentityWithBiometrics(data: data)
        result(ok)
      } else {
        result(false)
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func storeIdentityWithBiometrics(data: Data) -> Bool {
    // Create an access control that requires biometry for retrieving the item
    var err: Unmanaged<CFError>?
    guard let access = SecAccessControlCreateWithFlags(nil,
                                                      kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                                                      .biometryAny,
                                                      &err) else {
      return false
    }

    let key = "nexus.identity.biometric"
    let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                kSecAttrAccount as String: key,
                                kSecValueData as String: data,
                                kSecAttrAccessControl as String: access]
    SecItemDelete(query as CFDictionary)
    let status = SecItemAdd(query as CFDictionary, nil)
    return status == errSecSuccess
  }

  private func storeIdentity(data: Data) -> Bool {
    // Simple store without biometric protection (existing behavior)
    let key = "nexus.identity"
    let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                kSecAttrAccount as String: key,
                                kSecValueData as String: data,
                                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
    SecItemDelete(query as CFDictionary)
    let status = SecItemAdd(query as CFDictionary, nil)
    return status == errSecSuccess
  }

  private func wipeIdentity() -> Bool {
    var success = true
    // delete non-biometric
    let key = "nexus.identity"
    var query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                kSecAttrAccount as String: key]
    var status = SecItemDelete(query as CFDictionary)
    if !(status == errSecSuccess || status == errSecItemNotFound) { success = false }
    // delete biometric
    let keyb = "nexus.identity.biometric"
    query = [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: keyb]
    status = SecItemDelete(query as CFDictionary)
    if !(status == errSecSuccess || status == errSecItemNotFound) { success = false }
    return success
  }

  private func getIdentityWithBiometrics() -> Data? {
    let key = "nexus.identity.biometric"
    let prompt = "Authenticate to access your identity"
    let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                kSecAttrAccount as String: key,
                                kSecReturnData as String: kCFBooleanTrue as Any,
                                kSecUseOperationPrompt as String: prompt]
    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    if status == errSecSuccess {
      if let data = item as? Data { return data }
    }
    return nil
  }

  private func metadataFileURL() -> URL? {
    let fm = FileManager.default
    if let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
      try? fm.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
      return dir.appendingPathComponent("nexus_meta.json")
    }
    return nil
  }

  private func storeMetadata(json: String) -> Bool {
    guard let url = metadataFileURL() else { return false }
    do {
      try json.write(to: url, atomically: true, encoding: .utf8)
      return true
    } catch {
      return false
    }
  }

  private func getMetadata() -> String? {
    guard let url = metadataFileURL() else { return nil }
    do {
      let txt = try String(contentsOf: url, encoding: .utf8)
      return txt
    } catch {
      return nil
    }
  }
}
