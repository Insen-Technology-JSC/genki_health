
import Foundation

struct EnvironmentConfig {
    static let baseApiUrl: String = {
        #if DEBUG
        return "https://api.insentecs.cloud"
        #else
        return "https://api.insentecs.com"
        #endif
    }()
    static let baseAuthUrl: String = {
        #if DEBUG
        return "https://auth.insentecs.cloud"
        #else
        return "https://auth.insentecs.com"
        #endif
    }()
    
    
    
    static let firebaseUrl: String = {
        #if DEBUG
        return "https://dev-genki-notifications-default-rtdb.firebaseio.com/health_data/"
        #else
        return "https://genki-notifications-default-rtdb.firebaseio.com/health_data/"
        #endif
    }()
}
