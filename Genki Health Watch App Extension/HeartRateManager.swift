import SwiftUI
import HealthKit
import os

class HeartRateManager: NSObject, ObservableObject, HKLiveWorkoutBuilderDelegate, HKWorkoutSessionDelegate {
    
    @Published var heartRate: Double = 0.0
    @Published var showToast: Bool = false
    @Published var toastMessage: String = ""
    
    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var lastRecordedDate: Date?
    
    // ✅ Thêm biến lưu danh sách home
      @Published var homes: [Home] = []
      @Published var users: [User] = []
      @Published var selectedHome: Home? = nil
      @Published var selectedUser: User? = nil
      @Published var isLoadingHomes = false
      @Published var homeError: String? = nil
    
    
    private let logger = Logger(subsystem: "com.yourApp.HeartRate", category: "Workout")
    

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
    
    
    func checkAuthorizationAndStart() {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        healthStore.getRequestStatusForAuthorization(toShare: Set<HKSampleType>(), read: [heartRateType]) { [weak self] status, error in
            guard let self = self else { return }
            self.logger.debug("❌ Authorization failed: \(status.rawValue)")
//            case unknown = 0
//            case shouldRequest = 1
//            case unnecessary = 2
            switch status {
            case .unnecessary: //2
                // Đã cấp quyền, tự start workout
                DispatchQueue.main.async { self.startWorkout() }
            case .shouldRequest:
                // Chưa cấp quyền, yêu cầu user
                DispatchQueue.main.async { self.requestAuthorization() }
            case .unknown:
                print("⚠️ Unknown authorization status")
            @unknown default:
                break
            }
        }
    }

    func requestAuthorization() {
        let healthStore = HKHealthStore()
        let typesToShare: Set = [
            HKQuantityType.workoutType()
        ]
        let typesToRead: Set = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!
        ]

        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, error in
            if !success {
                print("❌ Không được cấp quyền HealthKit: \(String(describing: error))")
            } else {
                print("✅ Đã được cấp quyền HealthKit")
                self.startWorkout()
            }
        }
    }
    
    // MARK: - Start Workout
    func startWorkout() {
        logger.error("start workout session")
        if session != nil { stopWorkout() }
        logger.error("start workout session 1")
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .other
        configuration.locationType = .indoor
        
        do {
            session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            session?.delegate = self
            session?.startActivity(with: Date())
            
            builder = session?.associatedWorkoutBuilder()
            builder?.delegate = self
            builder?.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
            
            builder?.beginCollection(withStart: Date()) { success, error in
                if let error = error {
                    self.logger.error("Failed to begin collection: \(error.localizedDescription)")
                } else {
                    self.logger.debug("✅ Workout collection started")
                }
            }
            
        } catch {
            logger.error("Failed to start workout session: \(error.localizedDescription)")
        }
    }
    
    func stopWorkout() {
        builder?.endCollection(withEnd: Date()) { success, error in
            if let error = error { self.logger.error("Failed to end collection: \(error.localizedDescription)") }
        }
        builder?.finishWorkout { workout, error in
            if let error = error { self.logger.error("Finish workout error: \(error.localizedDescription)") }
            else { self.logger.debug("✅ Workout finished") }
        }
        session?.end()
        session = nil
        builder = nil
        lastRecordedDate = nil
    }
    
    // MARK: - HKLiveWorkoutBuilderDelegate
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) { }
    
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder,
                        didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType,
                  quantityType.identifier == HKQuantityTypeIdentifier.heartRate.rawValue else { continue }
            
            if let hr = workoutBuilder.statistics(for: quantityType)?
                .mostRecentQuantity()?
                .doubleValue(for: HKUnit(from: "count/min")) {
                DispatchQueue.main.async {
                    HttpHelper.uploadHeartRate(self.heartRate)
                    self.heartRate = hr
                }
//                DispatchQueue.main.async {
//                    self.heartRate = hr
//                   
//                    let now = Date()
//                    if self.lastRecordedDate == nil || now.timeIntervalSince(self.lastRecordedDate!) >= 30 {
//                        self.lastRecordedDate = now
//                        self.toastMessage = "💓 Heart rate: \(Int(hr)) bpm"
//                        self.showToast = true
//                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
//                            self.showToast = false
//                        }
//                        self.logger.debug("🕑 2-min heart rate recorded: \(Int(hr)) bpm")
//                    }
//                }
            }
        }
    }
    
    // MARK: - HKWorkoutSessionDelegate
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
//        logger.debug("Workout state changed: \(fromState.rawValue) -> \(toState.rawValue)")
        logger.debug("🏋️ Session changed: \(fromState.rawValue) → \(toState.rawValue)") //.notStarted (1) -> .running (2) 

    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        logger.error("Workout session failed: \(error.localizedDescription)")
    }
}
