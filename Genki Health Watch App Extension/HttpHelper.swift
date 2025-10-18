import Foundation
import Security

struct CredentialResponse: Codable {
    let id: String
    let app_id: String
    let secret: String
}

struct Home:Identifiable, Codable {
    var id: String { hub_id }
    let name: String
    let hub_id: String
}

struct User:Identifiable, Codable {
    var id: String { user_id }
    let name: String
    let user_id: String
}

final class HttpHelper {
   static func uploadHeartRate(_ value: Double) {
        let url = URL(string: "https://fastlane-ex-v1-64fbc-default-rtdb.firebaseio.com/heart_rate.json")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let data: [String: Any] = [
            "timestamp": Date().timeIntervalSince1970,
            "value": value
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: data)
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error = error {
                print("Error: \(error.localizedDescription)")
            } else {
                print("Uploaded successfully, hub_id:\(LiveData.hubId),user_id:\(LiveData.userId)")
            }
        }
        task.resume()
    }
    
    static func fetchCredential(appId: String, token: String, completion: @escaping (CredentialResponse?) -> Void) {
            // 1️⃣ Tạo URL
            let urlString = "https://api.insentecs.cloud/management/v1/credential/app/\(appId)"
            guard let url = URL(string: urlString) else {
                print("❌ Invalid URL")
                completion(nil)
                return
            }
            
            // 2️⃣ Tạo request
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Accept")

            // 3️⃣ Gọi API
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                // 4️⃣ Xử lý lỗi mạng
                if let error = error {
                    print("❌ Request error:", error)
                    completion(nil)
                    return
                }
                
                // 5️⃣ Kiểm tra mã phản hồi HTTP
                if let httpResponse = response as? HTTPURLResponse {
                    guard (200...299).contains(httpResponse.statusCode) else {
                        print("❌ Server returned status:", httpResponse.statusCode)
                        completion(nil)
                        return
                    }
                }
                
                // 6️⃣ Parse JSON trả về
                if let data = data {
                    do {
                        
                      
                        let result = try JSONDecoder().decode(CredentialResponse.self, from: data)
                        completion(result)
                    } catch {
                        print("❌ JSON decode error:", error)
                        completion(nil)
                    }
                } else {
                    completion(nil)
                }
            }
            
            task.resume()
        }

   static func getToken(clientId: String, clientSecret: String, completion: @escaping (String?) -> Void) {
        // 1️⃣ Tạo URL
        guard let url = URL(string: "https://auth.insentecs.cloud/oauth2/token") else {
            completion(nil)
            return
        }

        // 2️⃣ Tạo request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        // 3️⃣ Tạo header Authorization: Basic <base64(clientId:clientSecret)>
        let credentials = "\(clientId):\(clientSecret)"
        guard let encodedCredentials = credentials.data(using: .utf8)?.base64EncodedString() else {
            completion(nil)
            return
        }
        request.addValue("Basic \(encodedCredentials)", forHTTPHeaderField: "Authorization")
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        // 4️⃣ Tạo body
        let bodyString = "grant_type=client_credentials"
        request.httpBody = bodyString.data(using: .utf8)

        // 5️⃣ Gửi request
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Request error:", error)
                completion(nil)
                return
            }

            guard let data = data else {
                completion(nil)
                return
            }

            // 6️⃣ Parse JSON response
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("✅ Response JSON:", json)
                    if let token = json["access_token"] as? String {
                        completion(token)
                        return
                    }
                }
                completion(nil)
            } catch {
                print("❌ JSON parse error:", error)
                completion(nil)
            }
        }

        task.resume()
    }
    
    static func getHomes(token: String, completion: @escaping ([Home]?) -> Void) {
        guard let url = URL(string: "https://api.insentecs.cloud/things/v1/app/homes") else {
            completion(nil)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Request error:", error)
                completion(nil)
                return
            }

            guard let data = data else {
                completion(nil)
                return
            }

            do {
                let homes = try JSONDecoder().decode([Home].self, from: data)
                print("✅ Homes:", homes)
                completion(homes)
            } catch {
                print("❌ JSON decode error:", error)
                completion(nil)
            }
        }

        task.resume()
    }
    
    static func getUsers(token: String,hubId: String, completion: @escaping ([User]?) -> Void) {
        //https://api.insentecs.cloud/things/v1/app/home/{hub_id}/users
        guard let url = URL(string: "https://api.insentecs.cloud/things/v1/app/home/\(hubId)/users") else {
            completion(nil)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Request error:", error)
                completion(nil)
                return
            }

            guard let data = data else {
                completion(nil)
                return
            }

            do {
                let users = try JSONDecoder().decode([User].self, from: data)
                print("✅ Users:", users)
                completion(users)
            } catch {
                print("❌ JSON decode error:", error)
                completion(nil)
            }
        }

        task.resume()
    }

    
}
