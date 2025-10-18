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
    

    override init() {
        super.init()
    }
    

    func checkAuthorizationAndStart() {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let oxygenSaturationType = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation)!
        let bodyTempType = HKQuantityType.quantityType(forIdentifier: .bodyTemperature)!
        healthStore.getRequestStatusForAuthorization(toShare: Set<HKSampleType>(), read: [heartRateType,oxygenSaturationType,bodyTempType]) { [weak self] status, error in
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
            guard let quantityType = type as? HKQuantityType else { continue }

            // Lấy thống kê của loại dữ liệu vừa thu thập
            guard let statistics = workoutBuilder.statistics(for: quantityType),
                  let quantity = statistics.mostRecentQuantity() else { continue }

            DispatchQueue.main.async {
                
                switch quantityType.identifier {
                case HKQuantityTypeIdentifier.heartRate.rawValue:
                    let hr = quantity.doubleValue(for: HKUnit(from: "count/min"))
                    self.heartRate = hr
                  

                case HKQuantityTypeIdentifier.oxygenSaturation.rawValue:
                    let spo2 = quantity.doubleValue(for: HKUnit.percent()) * 100 // convert 0.97 → 97
                    self.spo2 = spo2
                   

                case HKQuantityTypeIdentifier.bodyTemperature.rawValue:
                    let temp = quantity.doubleValue(for: HKUnit.degreeCelsius())
                    self.bodyTemperature = temp
                default:
                    break
                }
                HttpHelper.uploadHealthDataToFirebase(self.heartRate,self.spo2,self.bodyTemperature)
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
