import SwiftUI
import HealthKit
import os

class HealthManager: NSObject, ObservableObject, HKLiveWorkoutBuilderDelegate, HKWorkoutSessionDelegate {
    
    @Published var spo2: Double = 0.0
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
    
    func initMonitors() {
        let duration = 120.0 // inta
        monitors[.spo2Low] = AlertMonitor(
            event: .spo2Low,
            threshold: 96.0,
            duration: duration,
            isGreaterThan: false,
            onTrigger: handleAlert
        )
        monitors[.heartRateHigh] = AlertMonitor(
            event: .heartRateHigh,
            threshold: 100.0,
            duration: duration,
            isGreaterThan: true,
            onTrigger: handleAlert
        )
        monitors[.heartRateLow] = AlertMonitor(
            event: .heartRateHigh,
            threshold: 50.0,
            duration: duration,
            isGreaterThan: false,
            onTrigger: handleAlert
        )
        
        monitors[.bodyTemperatureHigh] = AlertMonitor(
            event: .bodyTemperatureHigh,
            threshold: 38.0,
            duration: duration,
            isGreaterThan: true,
            onTrigger: handleAlert
        )
    }
    
    
    
    
    func checkAuthorizationAndStart() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let oxygenSaturationType = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation)!
        let bodyTempType = HKQuantityType.quantityType(forIdentifier: .bodyTemperature)!
        healthStore.getRequestStatusForAuthorization(toShare: Set<HKSampleType>(), read: [heartRateType,oxygenSaturationType,bodyTempType]) { [weak self] status, error in
            guard let self = self else { return }
            self.logger.debug("✅ Authorization value: \(status.rawValue)")
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
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .oxygenSaturation)!,
            HKQuantityType.quantityType(forIdentifier: .bodyTemperature)!
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
    
    
    func startWorkout() {
        logger.info("🏋️ Starting workout session...")
        
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
                    self.logger.error("❌ Begin collection failed: \(error.localizedDescription)")
                } else {
                    self.logger.info("✅ Workout collection started successfully")
                }
            }
            
        } catch {
            logger.error("❌ Failed to start workout session: \(error.localizedDescription)")
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
            guard let quantityType = type as? HKQuantityType else { continue }
            
            // Lấy thống kê của loại dữ liệu vừa thu thập
            guard let statistics = workoutBuilder.statistics(for: quantityType),
                  let quantity = statistics.mostRecentQuantity() else { continue }
            
            DispatchQueue.main.async {
                
                switch quantityType.identifier {
                case HKQuantityTypeIdentifier.heartRate.rawValue:
                    let hr = quantity.doubleValue(for: HKUnit(from: "count/min"))
                    self.heartRate = hr
                    self.queryLatestSpO2 { value in
                        if let spo2 = value {
                            self.spo2 = spo2
                        } else {
                            self.logger.info("Không lấy được SpO2")
                        }
                    }
                    break
                default:
                    break
                }
                
                self.monitors[.spo2Low]?.update(value: self.spo2)
                self.monitors[.heartRateLow]?.update(value: self.heartRate)
                self.monitors[.heartRateHigh]?.update(value: self.heartRate)
                HttpHelper.uploadHealthDataToFirebase(self.heartRate,self.spo2,self.bodyTemperature)
            }
        }
    }
    
    
    
    private func handleAlert(value: Double,event: HealthEventType) {
        HttpHelper.sendEmergencyAlert(token: LiveData.token, hubId: LiveData.hubId, userId: LiveData.userId, eventType: event.rawValue)
        self.logger.info("✅ handle alert event:\(event.rawValue),value: \(value)")
        DispatchQueue.main.async {
            self.showToast = true
            self.toastMessage = "⚠️ \(event.rawValue): \(String(format: "%.1f", value))"
            print("Alert triggered for \(event.rawValue): \(value)")
        }
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
                print("❌ Query Body Temp failed: \(error.localizedDescription)")
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
                print("❌ Query SpO2 failed: \(error.localizedDescription)")
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
        logger.debug("🏋️ Session changed: \(fromState.rawValue) → \(toState.rawValue)") //.notStarted (1) -> .running (2)
        
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        logger.error("Workout session failed: \(error.localizedDescription)")
    }
}
