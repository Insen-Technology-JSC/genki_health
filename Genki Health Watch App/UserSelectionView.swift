
import SwiftUI

struct UserSelectionView: View {
    
    @StateObject private var hrManager = HeartRateManager()
    @State private var navigateToMonitor = false
    
    var body: some View {
        NavigationStack{
            VStack {
                List(hrManager.users) {user in
                    HStack {
                        Text(user.name.isEmpty ? "(No name)" : user.name)
                        Spacer()
                        if hrManager.selectedUser?.user_id == user.user_id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                    .contentShape(Rectangle())
                    .frame(height: 24)
                    .onTapGesture {
                        hrManager.selectedUser = user
                    }
                    .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                   
                }
                .frame(height: 140)
                Button(action: {
                    navigateToMonitor = true
                    LiveData.userId = hrManager.selectedUser?.user_id ?? ""
                    StorageHelper.save(key: kUserId, data: LiveData.userId)
                    StorageHelper.save(key: kUserName, data: hrManager.selectedUser?.name ??
                    "")
                }) {
                    Text("Confirm")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(hrManager.selectedUser == nil ? Color.gray.opacity(0.3) : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding()
                .disabled(hrManager.selectedUser == nil)
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
                hrManager.fetchUsers(token:LiveData.token, hubId: LiveData.hubId)
            }
            .navigationTitle("Select Home")
        }
    }
}
