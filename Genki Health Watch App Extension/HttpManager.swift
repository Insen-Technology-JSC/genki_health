

import SwiftUI
import HealthKit
import os

class HttpManager: NSObject, ObservableObject {

    
    // ✅ Thêm biến lưu danh sách home
      @Published var homes: [Home] = []
      @Published var users: [User] = []
      @Published var selectedHome: Home? = nil
      @Published var selectedUser: User? = nil
      @Published var isLoadingHomes = false
      @Published var homeError: String? = nil
    
    
    private let logger = Logger(subsystem: "HeartRateManager", category: "Workout")
    

    override init() {
        super.init()
    }
    
    func checkRegisterApp(){
        let clientId = StorageHelper.load(key: kClienId) ?? ""
        let clientSecret = StorageHelper.load(key: kClienSecret) ?? ""
        if clientId.isEmpty && clientSecret.isEmpty {
            HttpHelper.getToken(clientId: clientId, clientSecret: clientSecret) { token in
                if let token = token {
                    print("✅ Access Token:", token)
                    LiveData.token = token
                } else {
                    print("❌ Failed to get token,register app.")
                    self.registerApp()
                }
            }
        } else {
            self.registerApp()
        }
    }
    
    func registerApp(){
        let appId = getOrCreateDeviceID()
        let token = TokenHelper.generateTokenWithExp(serviceId: appId, hours: 120)
        self.logger.debug("app id:\(appId),token:\(token) ")

        HttpHelper.fetchCredential(appId: appId, token: token) { response in
            if let credential = response {
                self.logger.debug("✅ client_id: \(credential.id), client_secret: \(credential.secret)")
                
                StorageHelper.save(key: kClienSecret, data: credential.secret)
                StorageHelper.save(key: kClienId, data: credential.id)
                self.getToken(clientId: credential.id, clientSecret: credential.secret)
                
            } else {
                self.logger.debug("❌ Failed to fetch credential")
            }
        }
    }
    
    func getToken(clientId: String,clientSecret: String){
        HttpHelper.getToken(clientId: clientId, clientSecret: clientSecret) { token in
            if let token = token {
                self.logger.debug("✅access token: \(token)")
                LiveData.token = token
                DispatchQueue.main.async {
                    self.isLoadingHomes = true
                    self.homeError = nil
                }
                
                if(StorageHelper.load(key: kHubId) == nil){
                    self.fetchHomes(token: token)
                }
            
            } else {
                self.logger.debug("❌ Failed to get token")
            }
        }
    }
    
    func loadDataToCache(){
        self.logger.debug("Load data to cache")
        LiveData.hubId = StorageHelper.load(key: kHubId) ?? ""
        LiveData.userId = StorageHelper.load(key: kUserId) ?? ""
        LiveData.userName = StorageHelper.load(key: kUserName) ?? ""
        
    }
    
    func fetchHomes(token: String){
        HttpHelper.getHomes(token: token) { homes in
            if let homes = homes {
                DispatchQueue.main.async {
                    self.isLoadingHomes = false
                    self.homes = homes
                    self.fetchUsers(token: token, hubId: "IST-GWH-2102-0001C031E907-L003032300001")
                }
            } else {
                self.logger.debug("❌ Failed to fetch homes")
                DispatchQueue.main.async {
                    self.isLoadingHomes = true
                    self.homeError = "Failed to fetch homes"
                }
            }
        }
    }
    
    func fetchUsers(token: String,hubId: String){
        HttpHelper.getUsers(token: token, hubId: hubId) { users in
            if let users = users {
                DispatchQueue.main.async {
                    self.users = users
                }
            } else {
                self.logger.debug("❌ Failed to fetch homes")
                DispatchQueue.main.async {
                    self.isLoadingHomes = true
                    self.homeError = "Failed to fetch homes"
                }
            }
        }
    }
    
    func getOrCreateDeviceID() -> String {
        if let existingID = StorageHelper.load(key: kDeviceId) {
            return existingID;
        } else {
            let newID = "GKA-" + UUID().uuidString
            StorageHelper.save(key: kDeviceId, data: newID)
            return newID
        }
    }

}
