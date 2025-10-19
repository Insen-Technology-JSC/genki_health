import Foundation

final class AlertMonitor {
    let event: HealthEventType
    let threshold: Double
    let duration: TimeInterval        // Thời gian cần duy trì vượt ngưỡng (vd: 60s)
    let cooldown: TimeInterval        // Thời gian nghỉ giữa 2 cảnh báo (vd: 300s)
    let isGreaterThan: Bool           // true = alert khi > threshold, false = alert khi < threshold
    let onTrigger: (Double,HealthEventType) -> Void   // Callback khi alert xảy ra
    
    private var startTime: Date?
    private var lastAlertTime: Date?
    
    init(
        event: HealthEventType,
        threshold: Double,
        duration: TimeInterval,
        cooldown: TimeInterval = 0,
        isGreaterThan: Bool,
        onTrigger: @escaping (Double,HealthEventType) -> Void
    ) {
        self.event = event
        self.threshold = threshold
        self.duration = duration
        self.cooldown = cooldown
        self.isGreaterThan = isGreaterThan
        self.onTrigger = onTrigger
    }
    
    func update(value: Double) {
        let now = Date()
        let isTriggered = isGreaterThan ? value > threshold : value < threshold
        
        if isTriggered {
            if startTime == nil { startTime = now }
            if let start = startTime,
               now.timeIntervalSince(start) >= duration {
                if lastAlertTime == nil || now.timeIntervalSince(lastAlertTime!) >= cooldown {
                    lastAlertTime = now
                    print("update, onTrigger|event: \(event)")
                    onTrigger(value,event)
                    startTime = nil
                }
            }
        } else {
            // Reset nếu trở lại bình thường
            print("update, startTime = nil. event: \(event)")
            startTime = nil
        }
    }
}
