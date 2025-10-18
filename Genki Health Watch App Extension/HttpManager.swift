

import SwiftUI
import HealthKit
import os

class HttpManager: NSObject, ObservableObject {
    
    
    // ✅ Thêm biến lưu danh sách home
      @Published var homes: [Home] = []
      @Published var users: [User] = []
      @Published var selectedHome: Home? = nil
      @Published var selectedUser: User? = nil
      @Published var isLoadingHomes = false
      @Published var homeError: String? = nil
    
    
    private let logger = Logger(subsystem: "com.yourApp.HeartRate", category: "Workout")
    
}
