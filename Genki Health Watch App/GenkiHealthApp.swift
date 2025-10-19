
import SwiftUI

@main
struct GenkiHealthApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var healthManager = HealthManager()

    var body: some Scene {
        WindowGroup {
            if ((StorageHelper.load(key: kHubId)?.isEmpty) == true || (StorageHelper.load(key: kUserId)?.isEmpty) == true) {
                // ❌ HomeSelectionView KHÔNG dùng background task
                HomeSelectionView()
                    .environmentObject(healthManager)
            }  else {
                // ✅ MonitorHealthView có HealthManager
                MonitorHealthView()
                    .environmentObject(healthManager)
                    .onChange(of: scenePhase) { newPhase in
                        switch newPhase {
                        case .background:
                            healthManager.scheduleBackgroundRefresh()
                        default:
                            break
                        }
                    }
            }
        }
    }
}


