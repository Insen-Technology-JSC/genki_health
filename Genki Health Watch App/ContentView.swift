import SwiftUI

struct ContentView: View {
    @StateObject private var hrManager = HeartRateManager()

    var body: some View {
        ZStack {
            VStack(spacing: 12) {
                Text("❤️ Heart Rate")
                    .font(.headline)
                Text("\(Int(hrManager.heartRate)) bpm")
                    .font(.title2)
            }

            if hrManager.showToast {
                Text(hrManager.toastMessage)
                    .padding(8)
                    .background(Color.black.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(.easeInOut, value: hrManager.showToast)
    }
}
