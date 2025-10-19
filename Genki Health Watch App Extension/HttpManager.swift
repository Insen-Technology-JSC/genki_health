

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
        print("HttpManager,check register app, client_id: \(clientId), client_secret: \(clientSecret)")
        if clientId.isEmpty == false && clientSecret.isEmpty == false {
            HttpHelper.getToken(clientId: clientId, clientSecret: clientSecret) { token in
                if let token = token {
                    print("✅ Access Token:", token)
                    LiveData.token = token
                    self.fetchHomes(token:LiveData.token)
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
        self.logger.debug("HttpManager, register app with id:\(appId),token:\(token) ")

        HttpHelper.fetchCredential(appId: appId, token: token) { response in
            if let credential = response {
                self.logger.debug("HttpManager,register app client_id: \(credential.id), client_secret: \(credential.secret)")
                StorageHelper.save(key: kClienSecret, data: credential.secret)
                StorageHelper.save(key: kClienId, data: credential.id)
                self.getToken(clientId: credential.id, clientSecret: credential.secret)
                
            } else {
                self.logger.debug("HttpManager,register app Failed to fetch credential")
            }
        }
    }
    
    func getToken(clientId: String,clientSecret: String){
        HttpHelper.getToken(clientId: clientId, clientSecret: clientSecret) { token in
            if let token = token {
                self.logger.debug("HttpManager,get access token: \(token)")
                LiveData.token = token
                DispatchQueue.main.async {
                    self.isLoadingHomes = true
                    self.homeError = nil
                }
                let hubIdCache = StorageHelper.load(key: kHubId) ?? ""
                
                if(hubIdCache.isEmpty == true){
                    self.fetchHomes(token: token)
                }
            
            } else {
                self.logger.debug("HttpManager,get Failed to get token")
            }
        }
    }
    
    func loadDataToCache(){
        self.logger.debug("HttpManager, Load data to cache")
        LiveData.hubId = StorageHelper.load(key: kHubId) ?? ""
        LiveData.userId = StorageHelper.load(key: kUserId) ?? ""
        LiveData.userName = StorageHelper.load(key: kUserName) ?? ""
        
    }
    
    func fetchHomes(token: String){
        HttpHelper.getHomes(token: token) { homes in
            self.logger.debug("HttpManager, Fetch homes | token: \(token)")
            if let homes = homes {
                DispatchQueue.main.async {
                    self.isLoadingHomes = false
                    self.homes = homes
                    if(LiveData.hubId.isEmpty == false){
                        self.fetchUsers(token: token, hubId: LiveData.hubId)
                    }
                    
                }
            } else {
                self.logger.debug("HttpManager, Failed to fetch homes")
                DispatchQueue.main.async {
                    self.isLoadingHomes = true
                    self.homeError = "HttpManager, Failed to fetch homes"
                }
            }
        }
    }
    
    func fetchUsers(token: String,hubId: String){
        self.logger.debug("HttpManager,fetchUsers token: \(token) hubId: \(hubId)")
        HttpHelper.getUsers(token: token, hubId: hubId) { users in
            if let users = users {
                DispatchQueue.main.async {
                    self.users = users
                }
            } else {
                self.logger.debug("HttpManager,Failed to fetch users")
                DispatchQueue.main.async {
                    self.isLoadingHomes = true
                    self.homeError = "HttpManager, Failed to fetch users"
                }
            }
        }
    }
    
    func getOrCreateDeviceID() -> String {
        let existingID = StorageHelper.load(key: kDeviceId) ?? ""
        if existingID.isEmpty == false {
            return existingID;
        } else {
            let newID = "GKA-" + UUID().uuidString
            StorageHelper.save(key: kDeviceId, data: newID)
            return newID
        }
    }

}
