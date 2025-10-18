
import SwiftUI

@main
struct GenkiHealthApp: App {
    var body: some Scene {
        WindowGroup {
            if ((StorageHelper.load(key: kHubId)?.isEmpty) != nil) {
                MonitorHealthView()
            }else{
                HomeSelectionView()
            }

        }
    }
}
