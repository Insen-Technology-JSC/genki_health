import Foundation
import SwiftJWT

struct MyClaims: Claims {
    let exp: UInt32
    let sub: String
    let iat: UInt32
    let iss: String
    let jti: String

}

class TokenHelper {
    static func generateTokenWithExp(serviceId: String, hours: Int) -> String {
        guard !serviceId.isEmpty else { return "" }
        
        let now = Date()
        let exp = Calendar.current.date(byAdding: .hour, value: hours, to: now)!
        
        let claims = MyClaims(
            exp:UInt32(exp.timeIntervalSince1970),
            sub: "authen",
            iat: UInt32(now.timeIntervalSince1970),
            iss: "app",
            jti: UUID().uuidString,
        )
        
        var jwt = JWT(header: Header(kid: UUID().uuidString), claims: claims)
        
        do {
            let signer = JWTSigner.hs512(key: Data(serviceId.utf8))
            let signedJWT = try jwt.sign(using: signer)
            return signedJWT
        } catch {
            print("Error signing JWT: \(error)")
            return ""
        }
    }
}
