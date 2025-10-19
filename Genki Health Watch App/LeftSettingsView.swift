
import SwiftUI

struct LeftSettingsView: View {
    @State private var showConfirm = false
    @State private var cleared = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Button(role: .destructive) {
                    showConfirm = true
                } label: {
                    Text("Clear Settings")
                        .font(.system(size: 14, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding()
//                        .background(Color.red.opacity(0.9))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                .confirmationDialog(
                    "Are you sure you want to clear settings?",
                    isPresented: $showConfirm,
                    titleVisibility: .visible
                ) {
                    Button("Confirm", role: .destructive) {
                        clearSettings()
                    }
                    Button("Cancel", role: .cancel) { }
                }

                if cleared {
                    Text("✅ Settings cleared successfully!")
                        .foregroundColor(.green)
                        .transition(.opacity)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Settings")
        }
    }

    private func clearSettings() {
        // 👉 Thực hiện xóa dữ liệu tại đây
        StorageHelper.clearAllData()
        withAnimation {
            cleared = true
        }

        // Ẩn thông báo sau 2s
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                cleared = false
            }
        }
    }
}

#Preview {
    LeftSettingsView()
}
