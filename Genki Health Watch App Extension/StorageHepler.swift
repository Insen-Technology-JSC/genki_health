

import Foundation
import Security


let kDeviceId = "device_id"
let kClienSecret = "client_secret"
let kClienId = "client_id"
let kHubId = "hub_id"
let kUserId = "user_id"
let kUserName = "user_name"


final class StorageHelper {
    static func save(key: String, data: String) {
        if let data = data.data(using: .utf8) {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: key,
                kSecValueData as String: data
            ]
            
            // Xoá nếu key đã tồn tại
            SecItemDelete(query as CFDictionary)
            
            // Thêm mới
            SecItemAdd(query as CFDictionary, nil)
        }
    }

    static func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess, let data = dataTypeRef as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }

    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
    
    static func clearAllData(){
        save(key: kDeviceId, data: "")
        save(key: kClienSecret, data: "")
        save(key: kClienId, data: "")
        save(key: kHubId, data: "")
        save(key: kUserId, data: "")
    }
}
