
import SwiftUI
struct HomeSelectionView: View {
    
    @StateObject private var hrManager = HeartRateManager()
    @State private var navigateToMonitor = false
    
    var body: some View {
        NavigationStack{
            VStack {
                List(hrManager.homes) { home in
                    HStack {
                        Text(home.name.isEmpty ? "(No name)" : home.name)
                        Spacer()
                        if hrManager.selectedHome?.hub_id == home.hub_id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        hrManager.selectedHome = home
                    }
                }
                
                Spacer()
                
                Button(action: {
                    navigateToMonitor = true
                    LiveData.hubId = hrManager.selectedHome?.hub_id ?? ""
                    
                }) {
                    Text("Next")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(hrManager.selectedHome == nil ? Color.gray.opacity(0.3) : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding()
                .disabled(hrManager.selectedHome == nil)
                
                // 👉 Navigation trigger
                NavigationLink(
                    destination: MonitorHealthView(),
                    isActive: $navigateToMonitor
                ) {
                    EmptyView()
                }
                .hidden()
                
            }
            .onAppear {
                hrManager.fetchHomes(token:LiveData.token)
            }
            .navigationTitle("Select Home")
        }
    }
}
