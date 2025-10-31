import SwiftUI
import FamilyControls
import DeviceActivity

struct ContentView: View {
    @EnvironmentObject var screenTimeService: ScreenTimeService
    @StateObject private var monitorService = DeviceActivityMonitorService()
    @State private var showMonitoringSettings = false
    
    var body: some View {
        NavigationView {
            VStack {
                if !screenTimeService.isAuthorized {
                    VStack(spacing: 20) {
                        Image(systemName: "lock.shield")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("Screen Time Access Required")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("GuardTime needs permission to monitor screen time activity. This allows you to view family members' device usage.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        Button("Grant Access") {
                            Task {
                                await screenTimeService.requestAuthorization()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .padding()
                    }
                } else {
                    ZStack {
                        VStack(spacing: 0) {
                            // Info banner explaining data sources
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 8) {
                                    Image(systemName: "info.circle.fill")
                                        .foregroundColor(.blue)
                                    Text("Daily data updates automatically")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                
                                Text("Tap button above to enable real-time study time monitoring (6-10 PM)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                            .padding(.horizontal)
                            .padding(.top, 8)
                            
                            // Screen Time report view (full screen)
                            ScreenTimeReportView(screenTimeService: screenTimeService)
                        }
                        
                        // Floating monitoring button in top-right corner
                        VStack {
                            HStack {
                                Spacer()
                                
                                Button(action: {
                                    showMonitoringSettings.toggle()
                                }) {
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(monitorService.isMonitoring ? Color.green : Color.gray)
                                            .frame(width: 10, height: 10)
                                        
                                        Image(systemName: monitorService.isMonitoring ? "stop.circle.fill" : "play.circle.fill")
                                            .font(.system(size: 16))
                                        
                                        if !showMonitoringSettings {
                                            Text(monitorService.isMonitoring ? "Stop" : "Start")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                        }
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(monitorService.isMonitoring ? Color.red : Color.blue)
                                    .cornerRadius(20)
                                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                                }
                                .padding(.trailing, 16)
                                .padding(.top, 8)
                            }
                            
                            Spacer()
                        }
                        
                        // Expandable settings panel
                        if showMonitoringSettings {
                            VStack {
                                HStack {
                                    Spacer()
                                    
                                    VStack(alignment: .trailing, spacing: 12) {
                                        // Close button
                                        Button(action: {
                                            showMonitoringSettings = false
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 24))
                                                .foregroundColor(.gray)
                                        }
                                        
                                        VStack(spacing: 12) {
                                            // Explanation section
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("Study Time Monitoring")
                                                    .font(.caption)
                                                    .fontWeight(.bold)
                                                
                                                Text("Enables real-time tracking during study hours with updates every 2-5 minutes. Runs in background even when app is closed.")
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                                    .fixedSize(horizontal: false, vertical: true)
                                            }
                                            
                                            // Start/Stop monitoring button
                                            Button(action: {
                                                if monitorService.isMonitoring {
                                                    monitorService.stopMonitoring()
                                                } else {
                                                    monitorService.startMonitoring()
                                                }
                                            }) {
                                                HStack {
                                                    Image(systemName: monitorService.isMonitoring ? "stop.circle.fill" : "play.circle.fill")
                                                    Text(monitorService.isMonitoring ? "Stop Monitoring" : "Start Monitoring")
                                                }
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundColor(.white)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 10)
                                                .background(monitorService.isMonitoring ? Color.red : Color.blue)
                                                .cornerRadius(10)
                                            }
                                            
                                            if monitorService.isMonitoring {
                                                HStack(spacing: 4) {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .foregroundColor(.green)
                                                        .font(.caption2)
                                                    Text(monitorService.isCurrentlyStudyTime() ? "Actively monitoring" : "Will monitor at study time")
                                                        .font(.caption2)
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                            
                                            Divider()
                                            
                                            // Auto-monitor toggle
                                            VStack(alignment: .leading, spacing: 8) {
                                                Toggle(isOn: Binding(
                                                    get: { monitorService.autoMonitorDuringStudyTime },
                                                    set: { monitorService.updateAutoMonitoringSetting($0) }
                                                )) {
                                                    VStack(alignment: .leading, spacing: 2) {
                                                        Text("Auto-monitor study time")
                                                            .font(.caption)
                                                            .fontWeight(.medium)
                                                        Text("Starts/stops automatically each day")
                                                            .font(.caption2)
                                                            .foregroundColor(.secondary)
                                                    }
                                                }
                                                
                                                if monitorService.autoMonitorDuringStudyTime {
                                                    VStack(alignment: .leading, spacing: 6) {
                                                        Text("Study Hours")
                                                            .font(.caption2)
                                                            .foregroundColor(.secondary)
                                                        
                                                        HStack(spacing: 8) {
                                                            DatePicker("Start", selection: $monitorService.studyTimeStart, displayedComponents: .hourAndMinute)
                                                                .labelsHidden()
                                                                .frame(maxWidth: 90)
                                                            Text("to")
                                                                .font(.caption2)
                                                                .foregroundColor(.secondary)
                                                            DatePicker("End", selection: $monitorService.studyTimeEnd, displayedComponents: .hourAndMinute)
                                                                .labelsHidden()
                                                                .frame(maxWidth: 90)
                                                        }
                                                        
                                                        if monitorService.isCurrentlyStudyTime() {
                                                            HStack(spacing: 4) {
                                                                Image(systemName: "clock.fill")
                                                                    .font(.caption2)
                                                                Text("Currently in study time")
                                                                    .font(.caption2)
                                                            }
                                                            .foregroundColor(.orange)
                                                            .padding(.top, 2)
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                        .padding(12)
                                        .background(Color(.systemBackground))
                                        .cornerRadius(12)
                                        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                                    }
                                    .padding(.trailing, 16)
                                    .padding(.top, 50)
                                }
                                
                                Spacer()
                            }
                            .background(Color.black.opacity(0.3))
                            .onTapGesture {
                                showMonitoringSettings = false
                            }
                        }
                    }
                }
            }
            .navigationTitle("GuardTime")
            .onAppear {
                // Check authorization status when view appears
                screenTimeService.checkAuthorizationStatus()
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(ScreenTimeService())
}
