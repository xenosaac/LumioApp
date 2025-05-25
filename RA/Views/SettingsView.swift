import SwiftUI

struct SettingsView: View {
    @AppStorage("isDarkMode") private var isDarkMode = false
    @StateObject private var watchConnectivity = WatchConnectivityManager.shared
    
    var body: some View {
        NavigationView {
            Form {
                // Apple Watch Status
                Section(header: Text("Apple Watch")) {
                    // Apple Watch 状态
                    HStack {
                        Image(systemName: watchConnectivity.isConnected ? "applewatch.radiowaves.left.and.right" : "applewatch.slash")
                            .foregroundColor(watchConnectivity.isConnected ? .green : .red)
                            .frame(width: 25, height: 25)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Apple Watch")
                            Text(watchConnectivity.isConnected ? "Connected" : "Not Connected")
                                .font(.caption)
                                .foregroundColor(watchConnectivity.isConnected ? .green : .red)
                        }
                    }
                }
                
                
                    
                
                // About
                Section(header: Text("About")) {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                            .frame(width: 25, height: 25)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Version")
                            Text("1.0.0")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                    }
                }
                
                // Contact
                Section(header: Text("Contact")) {
                    HStack {
                        Image(systemName: "envelope")
                            .foregroundColor(.blue)
                            .frame(width: 25, height: 25)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Email")
                            Text("support@example.com")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
} 
