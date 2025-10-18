
import SwiftUI

struct HomeSelectionView: View {
    
    @StateObject private var httpManager = HttpManager()
    @State private var navigateToMonitor = false
    
    var body: some View {
        NavigationStack{
            VStack {
                List(httpManager.homes) { home in
                    HStack {
                        Text(home.name.isEmpty ? "(No name)" : home.name)
                        Spacer()
                        if httpManager.selectedHome?.hub_id == home.hub_id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                    .contentShape(Rectangle())
                    .frame(height: 24)
                    .onTapGesture {
                        httpManager.selectedHome = home
                    }
                    .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                   
                }
                .frame(height: 140)
                Button(action: {
                    navigateToMonitor = true
                    LiveData.hubId = httpManager.selectedHome?.hub_id ?? ""
                    StorageHelper.save(key: kHubId, data: LiveData.hubId)
                    
                }) {
                    Text("Next")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(httpManager.selectedHome == nil ? Color.gray.opacity(0.3) : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding()
                .disabled(httpManager.selectedHome == nil)
                // 👉 Navigation trigger
                NavigationLink(
                    destination: UserSelectionView(),
                    isActive: $navigateToMonitor
                ) {
                    EmptyView()
                }
                .hidden()
            }
            .onAppear {
                httpManager.checkRegisterApp();
                httpManager.fetchHomes(token:LiveData.token)
            }
            .navigationTitle("Select Home")
        }
    }
}
