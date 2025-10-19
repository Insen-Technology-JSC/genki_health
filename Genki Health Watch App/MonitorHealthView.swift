import SwiftUI

struct MonitorHealthView: View {
    @StateObject private var httpManager = HttpManager()
    @EnvironmentObject var healthManager: HealthManager
    
    // State để điều hướng hoặc trigger action
    @State private var navigateLeft = false
    @State private var navigateRight = false
    @State private var swipeDirection: String = ""
    
    var body: some View {
        NavigationStack{
            ZStack {
                VStack(spacing: 12) {
                    HStack {
                        Text("❤️Heart Rate:").font(.system(size: 14))
                        Spacer()
                        Text("\(Int(healthManager.heartRate)) bpm")
                            .font(.headline)
                    }
                    
                    HStack {
                        Text("🩸SpO₂:").font(.system(size: 14))
                        Spacer()
                        Text(String(format: "%.1f %%", healthManager.spo2))
                            .font(.headline)
                    }
                    
                    HStack {
                        Text("🌡️Body Temp:").font(.system(size: 14))
                        Spacer()
                        Text(String(format: "%.1f ℃", healthManager.bodyTemperature))
                            .font(.headline)
                    }
                }
                .padding()
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onEnded { value in
                            let horizontal = value.translation.width
                            let vertical = value.translation.height
                            
                            if abs(horizontal) > abs(vertical) {
                                if horizontal < -50 {
                                    // Swipe Left → mở Setting
                                    withAnimation {
                                        navigateLeft = true
                                    }
                                    
                                } else if horizontal > 50 {
                                    // Swipe Right → về Home
                                    withAnimation {
                                        navigateRight = true
                                    }
                                }
                            } else {
                                if vertical < -50 {
                                    
                                    // Swipe Up → reload dữ liệu
                                    //                                withAnimation {
                                    //                                    swipeDirection = "up"
                                    //                                    refreshData()
                                    //                                }
                                }
                            }
                        }
                )
                
                if healthManager.showToast {
                    Text(healthManager.toastMessage)
                        .padding(8)
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .transition(.opacity)
                        .zIndex(1)
                }
                
                // Điều hướng (NavigationLink ẩn)
                NavigationLink(destination: LeftSettingsView(), isActive: $navigateLeft) { EmptyView() }.hidden()
                NavigationLink(destination: RightSettingView(), isActive: $navigateRight) { EmptyView() }.hidden()
            }
            .onAppear {
                httpManager.loadDataToCache()
                healthManager.checkAuthorizationAndStart()
                healthManager.initMonitors()
                httpManager.getToken(
                    clientId: StorageHelper.load(key: kClienId) ?? "",
                    clientSecret: StorageHelper.load(key: kClienSecret) ?? ""
                )
            }
            .animation(.easeInOut, value: healthManager.showToast)
            .navigationBarBackButtonHidden(true)
        }
    }
    
}

