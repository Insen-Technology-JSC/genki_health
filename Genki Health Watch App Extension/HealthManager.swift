import SwiftUI
import HealthKit
import os

class HealthManager: NSObject, ObservableObject, HKLiveWorkoutBuilderDelegate, HKWorkoutSessionDelegate {
    
    @Published var spo2: Double = 0.0
    @Published var stepCount: Double = 0.0
    @Published var bodyTemperature: Double = 0.0
    @Published var heartRate: Double = 0.0
    @Published var showToast: Bool = false
    @Published var toastMessage: String = ""
    
    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var lastRecordedDate: Date?
    private let logger = Logger(subsystem: "HeartRateManager", category: "Workout")
    private var monitors: [HealthEventType: AlertMonitor] = [:]
    
    override init() {
        super.init()
    }
    
    func showToastMessage(_ message: String) {
        DispatchQueue.main.async {
            self.toastMessage = message
            withAnimation {
                self.showToast = true
            }
        }
        // Tự động ẩn sau 2 giây
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                self.showToast = false
            }
        }
    }
    
    func initMonitors() {
        monitors[.spo2Low] = AlertMonitor(
            event: .spo2Low,
            threshold: HealthConstants.spo2Low,
            duration: HealthConstants.alertDuration,
            isGreaterThan: false,
            onTrigger: handleAlert
        )
        
        monitors[.heartRateHigh] = AlertMonitor(
            event: .heartRateHigh,
            threshold: HealthConstants.hearRateHigh,
            duration: HealthConstants.alertDuration,
            isGreaterThan: true,
            onTrigger: handleAlert
        )
        
        monitors[.heartRateLow] = AlertMonitor(
            event: .heartRateLow,
            threshold: HealthConstants.hearRateLow,
            duration: HealthConstants.alertDuration,
            isGreaterThan: false,
            onTrigger: handleAlert
        )
    }
    
    func checkAuthorizationAndStart() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let oxygenSaturationType = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation)!
        let bodyTempType = HKQuantityType.quantityType(forIdentifier: .bodyTemperature)!
        let stepCountype = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        healthStore.getRequestStatusForAuthorization(toShare: Set<HKSampleType>(), read: [heartRateType,oxygenSaturationType,bodyTempType,stepCountype]) { [weak self] status, error in
            guard let self = self else { return }
            self.logger.debug("HealthManager.✅ Authorization value: \(status.rawValue)")
            switch status {
            case .unnecessary: //2
                // Đã cấp quyền, tự start workout
                DispatchQueue.main.async { self.startWorkout() }
            case .shouldRequest:
                // Chưa cấp quyền, yêu cầu user
                DispatchQueue.main.async { self.requestAuthorization() }
            case .unknown:
                self.logger.info("HealthManager,⚠️ Unknown authorization status")
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
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .oxygenSaturation)!,
            HKQuantityType.quantityType(forIdentifier: .bodyTemperature)!,
            HKQuantityType.quantityType(forIdentifier: .stepCount)!
        ]
        
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, error in
            if !success {
                self.logger.info("HealthManager,❌ Không được cấp quyền HealthKit: \(String(describing: error))")
            } else {
                self.logger.info("HealthManager,✅ Đã được cấp quyền HealthKit")
                self.startWorkout()
            }
        }
    }
    
    
    func startWorkout() {
        logger.info("HealthManager,🏋️ Starting workout session...")
        
        // Nếu đang có session cũ, dừng lại
        if session != nil {
            stopWorkout()
        }
        
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .other
        configuration.locationType = .indoor
        
        do {
            session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            builder = session!.associatedWorkoutBuilder()
            
            
            
            // Gắn datasource
            builder!.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
            
            session!.delegate = self
            builder!.delegate = self
            
            // ⚡ Bắt buộc: HealthStore phải start session
            healthStore.start(session!)
            
            // ⚡ Sau đó mới bắt đầu thu thập dữ liệu
            builder!.beginCollection(withStart: Date()) { success, error in
                if let error = error {
                    self.logger.error("HealthManager,❌ Begin collection failed: \(error.localizedDescription)")
                } else {
                    self.logger.info("HealthManager,✅ Workout collection started successfully")
                    self.scheduleBackgroundRefresh()
                }
            }
            
        } catch {
            logger.error("HealthManager,❌ Failed to start workout session: \(error.localizedDescription)")
        }
    }
    
    
    func stopWorkout() {
        builder?.endCollection(withEnd: Date()) { success, error in
            if let error = error { self.logger.error("HealthManager,Failed to end collection: \(error.localizedDescription)") }
        }
        builder?.finishWorkout { workout, error in
            if let error = error { self.logger.error("Finish workout error: \(error.localizedDescription)") }
            else { self.logger.debug("HealthManager,✅ Workout finished") }
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
            guard let quantityType = type as? HKQuantityType else { continue }
            
            // Lấy thống kê của loại dữ liệu vừa thu thập
            guard let statistics = workoutBuilder.statistics(for: quantityType),
                  let quantity = statistics.mostRecentQuantity() else { continue }
            
            DispatchQueue.main.async {
                let group = DispatchGroup()
                var spo2Value: Double = 0.0
                var stepCountValue: Double = 0.0
                var heartRateValue: Double = 0.0
                
                switch quantityType.identifier {
                case HKQuantityTypeIdentifier.heartRate.rawValue:
                    heartRateValue = quantity.doubleValue(for: HKUnit(from: "count/min"))
                    
                    group.enter()
                    self.queryLatestSpO2 { value in
                        if let v = value { spo2Value = v }
                        group.leave()
                    }
                    
                    group.enter()
                    self.fetchStepCount { value in
                        if let v = value { stepCountValue = v }
                        group.leave()
                    }
                    
                    group.notify(queue: .main) {
                        if (spo2Value != self.spo2 || heartRateValue != self.heartRate || stepCountValue != self.stepCount) {
                            self.spo2 = spo2Value
                            self.heartRate = heartRateValue
                            self.stepCount = stepCountValue
                            self.bodyTemperature = 0.0
                            
                            self.logger.info("✅ uploadHealthDataToFirebase heartRate:\(self.heartRate), spo2:\(self.spo2), stepCount:\(self.stepCount)")
                            HttpHelper.uploadHealthDataToFirebase(self.heartRate, self.spo2, self.bodyTemperature, self.stepCount)
                        }
                        self.monitors[.spo2Low]?.update(value: self.spo2)
                        self.monitors[.heartRateLow]?.update(value: self.heartRate)
                        self.monitors[.heartRateHigh]?.update(value: self.heartRate)
                    }
                default:
                    break
                }
                
            }
        }
    }
    
    func fetchStepCount(completion: @escaping (Double?) -> Void) {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            completion(nil)
            return
        }

        let now = Date()
        let twoMinAgo = now.addingTimeInterval(-3600) // 1h

        let predicate = HKQuery.predicateForSamples(withStart: twoMinAgo, end: now, options: [])

        let query = HKStatisticsQuery(quantityType: stepType,
                                      quantitySamplePredicate: predicate,
                                      options: .cumulativeSum) { _, result, error in
            guard let result = result, let sum = result.sumQuantity() else {
                DispatchQueue.main.async { completion(0) }
                return
            }
            let steps = sum.doubleValue(for: .count())
            DispatchQueue.main.async {
                self.logger.info("✅ Steps in last 2 min: \(steps)")
                completion(steps)
            }
        }

        healthStore.execute(query)

    }
    
    
    
    
    private func handleAlert(value: Double,event: HealthEventType) {
        HttpHelper.sendEmergencyAlert(token: LiveData.token, hubId: LiveData.hubId, userId: LiveData.userId, eventType: event.rawValue)
        self.logger.info("HealthManager,✅ handle alert event:\(event.rawValue),value: \(value)")
    }
    
    func queryLatestBodyTemperature(completion: @escaping (Double?) -> Void) {
        guard let tempType = HKQuantityType.quantityType(forIdentifier: .bodyTemperature) else {
            completion(nil)
            return
        }
        
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: tempType,
                                  predicate: nil,
                                  limit: 1,
                                  sortDescriptors: [sort]) { _, samples, error in
            if let error = error {
                self.logger.info("HealthManager,❌ Query Body Temp failed: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let sample = samples?.first as? HKQuantitySample else {
                completion(nil)
                return
            }
            
            let temp = sample.quantity.doubleValue(for: HKUnit.degreeCelsius())
            DispatchQueue.main.async {
                self.bodyTemperature = temp
                completion(temp)
            }
        }
        
        healthStore.execute(query)
    }
    
    func queryLatestSpO2(completion: @escaping (Double?) -> Void) {
        guard let spo2Type = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation) else {
            completion(nil)
            return
        }
        
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: spo2Type,
                                  predicate: nil,
                                  limit: 1,
                                  sortDescriptors: [sort]) { _, samples, error in
            if let error = error {
                self.logger.info("HealthManager,❌ Query SpO2 failed: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let sample = samples?.first as? HKQuantitySample else {
                completion(nil)
                return
            }
            
            let spo2 = sample.quantity.doubleValue(for: HKUnit.percent()) * 100
            DispatchQueue.main.async {
                self.spo2 = spo2   // cập nhật trực tiếp biến Published
                completion(spo2)   // trả về callback
            }
        }
        
        healthStore.execute(query)
    }
    
    // MARK: - HKWorkoutSessionDelegate
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        //        logger.debug("Workout state changed: \(fromState.rawValue) -> \(toState.rawValue)")
        logger.debug("HealthManager,🏋️ Session changed: \(fromState.rawValue) → \(toState.rawValue)") //.notStarted (1) -> .running (2)
        
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        logger.error("HealthManager,Workout session failed: \(error.localizedDescription)")
    }
}


extension HealthManager {
    
    /// Gọi hàm này sau khi startWorkout() để đăng ký background refresh
    func scheduleBackgroundRefresh() {
        let nextRefresh = Date().addingTimeInterval(60) // 1 phút sau
        WKExtension.shared().scheduleBackgroundRefresh(withPreferredDate: nextRefresh, userInfo: nil) { error in
            if let error = error {
                self.logger.error("HealthManager,❌ Failed to schedule background refresh: \(error.localizedDescription)")
            } else {
                self.logger.info("HealthManager,⏰ Background refresh scheduled at \(nextRefresh.formatted())")
            }
        }
    }
    
    /// AppDelegate hoặc SceneDelegate sẽ gọi hàm này khi hệ thống wake app
    func handleBackgroundTasks(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        for task in backgroundTasks {
            if let refreshTask = task as? WKApplicationRefreshBackgroundTask {
                self.logger.info("HealthManager,🔄 Handling background refresh task")
                
                // 1️⃣ Kiểm tra session còn đang chạy không
                if self.session == nil {
                    self.logger.info("HealthManager,⚠️ Session is nil, restarting workout...")
                    self.startWorkout()
                } else {
                    self.logger.info("HealthManager,✅ Session still active")
                }
                
                // 2️⃣ Push lại dữ liệu nếu cần
                HttpHelper.uploadHealthDataToFirebase(self.heartRate, self.spo2, self.bodyTemperature,self.stepCount)
                
                // 3️⃣ Lên lịch cho lần tiếp theo
                self.scheduleBackgroundRefresh()
                
                // 4️⃣ Đánh dấu task đã hoàn thành
                refreshTask.setTaskCompletedWithSnapshot(false)
            } else {
                task.setTaskCompletedWithSnapshot(false)
            }
        }
    }
}
