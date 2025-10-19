
import SwiftUI

struct UserSelectionView: View {
    
    @StateObject private var httpManager = HttpManager()
    @State private var navigateToMonitor = false
    @EnvironmentObject var healthManager: HealthManager
    var body: some View {
        NavigationStack{
            VStack {
                List(httpManager.users) {user in
                    HStack {
                        Text(user.name.isEmpty ? "(No name)" : user.name)
                        Spacer()
                        if httpManager.selectedUser?.user_id == user.user_id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                    .contentShape(Rectangle())
                    .frame(height: 24)
                    .onTapGesture {
                        httpManager.selectedUser = user
                    }
                    .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                   
                }
                .frame(height: 140)
                Button(action: {
                    navigateToMonitor = true
                    LiveData.userId = httpManager.selectedUser?.user_id ?? ""
                    StorageHelper.save(key: kUserId, data: LiveData.userId)
                    StorageHelper.save(key: kUserName, data: httpManager.selectedUser?.name ??
                    "")
                    
                }) {
                    Text("Confirm")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(httpManager.selectedUser == nil ? Color.gray.opacity(0.3) : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding()
                .background(Color.clear)
                .buttonStyle(.plain)
                .disabled(httpManager.selectedUser == nil)
                // 👉 Navigation trigger
                NavigationLink(
                    destination: MonitorHealthView().environmentObject(healthManager),
                    isActive: $navigateToMonitor
                ) {
                    EmptyView()
                }
                .hidden()
            }
            .onAppear {
                httpManager.fetchUsers(token:LiveData.token, hubId: LiveData.hubId)
            }
            .navigationTitle("Select Home")
        }
    }
}
