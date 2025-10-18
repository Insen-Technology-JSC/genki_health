import Foundation
import Security

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
                print("Uploaded successfully")
            }
        }
        task.resume()
    }
}
