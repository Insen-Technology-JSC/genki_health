import SwiftUI

struct MonitorHealthView: View {
    @StateObject private var hrManager = HealthManager()
    @StateObject private var httpManager = HttpManager()

    var body: some View {
        ZStack {
            VStack(spacing: 12) {
                HStack {
                        Text("❤️ Heart Rate:")
                        Spacer()
                        Text("\(Int(hrManager.heartRate)) bpm")
                            .font(.headline)
                    }

                    HStack {
                        Text("🩸 SpO₂:")
                        Spacer()
                        Text(String(format: "%.1f %%", hrManager.spo2))
                            .font(.headline)
                    }

                    HStack {
                        Text("🌡️ Body Temp:")
                        Spacer()
                        Text(String(format: "%.1f ℃", hrManager.bodyTemperature))
                            .font(.headline)
                    }
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
        .onAppear {
            httpManager.loadDataToCache()
            httpManager.getToken(clientId: StorageHelper.load(key: kClienId) ?? "", clientSecret:  StorageHelper.load(key: kClienSecret) ?? "")
            hrManager.checkAuthorizationAndStart()
        }
        .animation(.easeInOut, value: hrManager.showToast)
        .navigationBarBackButtonHidden(true)
    }
}
