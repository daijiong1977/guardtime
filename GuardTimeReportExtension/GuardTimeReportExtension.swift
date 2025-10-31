import SwiftUI
import DeviceActivity

// MARK: - Data Models
struct FamilyMember: Codable, Identifiable {
    let name: String
    let role: String
    let appleID: String
    var id: String { appleID }
}

struct AppUsageInfo: Identifiable {
    let id = UUID()
    let name: String
    let duration: TimeInterval
    let token: String
}

struct DailyActivityData {
    let date: Date
    let totalSocialTime: TimeInterval
    let socialTimeDuringStudyHours: TimeInterval
    let apps: [AppUsageInfo]
}

struct ChildActivityData: Identifiable {
    let id = UUID()
    let child: FamilyMember
    let todaySocialTime: TimeInterval
    let todayStudyTimeSocial: TimeInterval
    let todayTopApps: [AppUsageInfo]
    let weeklyHistory: [DailyActivityData]? // Only populated when history is requested
}

// MARK: - Helper Functions
/// Calculates actual app usage during study hours (6-10 PM) based on segment timing
/// IMPORTANT: This only returns accurate data when monitoring is active during study hours.
/// Without active monitoring, iOS doesn't provide hour-by-hour breakdowns, so we return 0.
func calculateStudyHourUsageForSegment(segmentInterval: DateInterval, appDuration: TimeInterval, date: Date) -> TimeInterval {
    let calendar = Calendar.current
    let now = Date()
    let dayStart = calendar.startOfDay(for: date)
    
    // Only calculate study time for today
    guard calendar.isDate(date, inSameDayAs: now) else {
        return 0
    }
    
    // Define study hours: 6 PM (18:00) to 10 PM (22:00)
    guard let studyStart = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: dayStart),
          let studyEnd = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: dayStart) else {
        return 0
    }
    
    let currentHour = calendar.component(.hour, from: now)
    
    // If it's before 6 PM, study time hasn't started yet - return 0
    if currentHour < 18 {
        return 0
    }
    
    // If it's during or after study hours, check if the segment contains study hour data
    // The segment usually spans the full day, so we can't accurately determine
    // WHEN during the day the app was used without active monitoring.
    // 
    // For accurate study time tracking, monitoring must be active during 6-10 PM.
    // Until then, return 0 to avoid showing estimated/incorrect data.
    
    // Only return study time if we're currently IN study hours or monitoring was active
    if currentHour >= 18 && currentHour < 22 {
        // We're currently in study hours - but without monitoring, we can't distinguish
        // whether the app usage happened NOW or earlier in the day
        // Return 0 until monitoring provides real-time data
        return 0
    }
    
    // If it's after 10 PM and the segment ends after study hours ended,
    // we might have some study hour usage, but without monitoring we can't tell
    return 0
}

// MARK: - Extension Entry Point
@main
struct GuardTimeReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        TotalActivityReport { configuration in
            TotalActivityView(configuration: configuration)
        }
    }
}

// MARK: - Report Scene
struct TotalActivityReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .init(rawValue: "ChildrenTabs")
    let content: (TotalActivityConfiguration) -> TotalActivityView
    
    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> TotalActivityConfiguration {
        var childrenActivities: [ChildActivityData] = []
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        for await datum in data {
            let user = datum.user
            
            var userName = "Unknown User"
            if let nameComponents = user.nameComponents {
                userName = PersonNameComponentsFormatter().string(from: nameComponents)
            } else if let appleID = user.appleID {
                userName = appleID.components(separatedBy: "@").first ?? appleID
            }
            
            guard user.role == .child else { continue }
            
            let userRole: String
            switch user.role {
            case .child: userRole = "Child"
            case .individual: userRole = "Individual"
            @unknown default: userRole = "Unknown"
            }
            
            var todaySocialTime: TimeInterval = 0
            var todayStudyTimeSocial: TimeInterval = 0
            var todayApps: [String: (TimeInterval, String)] = [:]
            var weeklyData: [Date: (socialTime: TimeInterval, studyTime: TimeInterval, apps: [String: (TimeInterval, String)])] = [:]
            
            // Process segments - each segment represents a specific day's data
            for await segment in datum.activitySegments {
                // Get the day this segment represents
                let segmentStartDay = calendar.startOfDay(for: segment.dateInterval.start)
                let segmentEndDay = calendar.startOfDay(for: segment.dateInterval.end)
                
                // Determine which day this segment belongs to
                // DeviceActivity uses .daily segment, so each segment should be one full day
                let segmentDay = segmentStartDay
                let isToday = calendar.isDate(segmentDay, inSameDayAs: today)
                
                var socialTimeThisDay: TimeInterval = 0
                var studyTimeThisDay: TimeInterval = 0
                var appsThisDay: [String: (TimeInterval, String)] = [:]
                
                for await category in segment.categories {
                    // Process ALL apps in this category
                    for await app in category.applications {
                        let appName = app.application.localizedDisplayName ?? "Unknown App"
                        let appDuration = app.totalActivityDuration
                        let tokenString = "\(app.application.token.hashValue)"
                        
                        // Track ALL apps (matches Apple Screen Time behavior)
                        if let existing = appsThisDay[appName] {
                            appsThisDay[appName] = (existing.0 + appDuration, existing.1)
                        } else {
                            appsThisDay[appName] = (appDuration, tokenString)
                        }
                        
                        // Custom social app list - track these 5 specific apps
                        let socialApps = ["snapchat", "tiktok", "messages", "instagram", "youtube"]
                        let appNameLower = appName.lowercased()
                        let isSocialApp = socialApps.contains { appNameLower.contains($0) }
                        
                        // If this is one of our monitored social apps, count towards social time
                        if isSocialApp {
                            socialTimeThisDay += appDuration
                            
                            // Calculate study hours usage for social apps
                            let studyHourUsage = calculateStudyHourUsageForSegment(
                                segmentInterval: segment.dateInterval,
                                appDuration: appDuration,
                                date: segmentDay
                            )
                            studyTimeThisDay += studyHourUsage
                        }
                    }
                }
                
                // Store data for this specific day
                if isToday {
                    todaySocialTime += socialTimeThisDay
                    todayStudyTimeSocial += studyTimeThisDay
                    for (appName, appData) in appsThisDay {
                        if let existing = todayApps[appName] {
                            todayApps[appName] = (existing.0 + appData.0, existing.1)
                        } else {
                            todayApps[appName] = appData
                        }
                    }
                } else {
                    // Store historical data for this specific day
                    if var existing = weeklyData[segmentDay] {
                        existing.socialTime += socialTimeThisDay
                        existing.studyTime += studyTimeThisDay
                        for (appName, appData) in appsThisDay {
                            if let existingApp = existing.apps[appName] {
                                existing.apps[appName] = (existingApp.0 + appData.0, existingApp.1)
                            } else {
                                existing.apps[appName] = appData
                            }
                        }
                        weeklyData[segmentDay] = existing
                    } else {
                        weeklyData[segmentDay] = (socialTimeThisDay, studyTimeThisDay, appsThisDay)
                    }
                }
            }
            
            let topApps = todayApps.map {
                AppUsageInfo(name: $0.key, duration: $0.value.0, token: $0.value.1)
            }.sorted { $0.duration > $1.duration }
            .prefix(5).map { $0 }
            
            // Create weekly history array ONLY if we have historical data
            // Order: Yesterday (most recent) to 7 days ago (farthest)
            var weeklyHistory: [DailyActivityData]? = nil
            if !weeklyData.isEmpty {
                var historyArray: [DailyActivityData] = []
                for i in 1...7 {
                    let date = calendar.date(byAdding: .day, value: -i, to: today)!
                    let dayStart = calendar.startOfDay(for: date)
                    
                    if let dayData = weeklyData[dayStart] {
                        let apps = dayData.apps.map {
                            AppUsageInfo(name: $0.key, duration: $0.value.0, token: $0.value.1)
                        }.sorted { $0.duration > $1.duration }
                        
                        historyArray.append(DailyActivityData(
                            date: dayStart,
                            totalSocialTime: dayData.socialTime,
                            socialTimeDuringStudyHours: dayData.studyTime,
                            apps: apps
                        ))
                    } else {
                        historyArray.append(DailyActivityData(
                            date: dayStart,
                            totalSocialTime: 0,
                            socialTimeDuringStudyHours: 0,
                            apps: []
                        ))
                    }
                }
                // Keep natural order: yesterday first, then older days
                weeklyHistory = historyArray
            }
            
            let child = FamilyMember(
                name: userName,
                role: userRole,
                appleID: user.appleID ?? UUID().uuidString
            )
            
            let childData = ChildActivityData(
                child: child,
                todaySocialTime: todaySocialTime,
                todayStudyTimeSocial: todayStudyTimeSocial,
                todayTopApps: topApps,
                weeklyHistory: weeklyHistory
            )
            
            childrenActivities.append(childData)
        }
        
        return TotalActivityConfiguration(childrenActivities: childrenActivities)
    }
}

struct TotalActivityConfiguration {
    let childrenActivities: [ChildActivityData]
}

// MARK: - Main View
struct TotalActivityView: View {
    let configuration: TotalActivityConfiguration
    @State private var selectedChildIndex = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if configuration.childrenActivities.isEmpty {
                    EmptyStateView()
                } else {
                    VStack(spacing: 0) {
                        ChildTabsBar(
                            children: configuration.childrenActivities.map { $0.child },
                            selectedIndex: $selectedChildIndex
                        )
                        .frame(height: 80)
                        
                        if selectedChildIndex < configuration.childrenActivities.count {
                            ChildActivityContentView(
                                activityData: configuration.childrenActivities[selectedChildIndex]
                            )
                        }
                    }
                }
            }
        }
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "figure.2.and.child.holdinghands")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text("No Children Found")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Make sure Family Sharing is set up\nwith child accounts")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(40)
    }
}

struct ChildTabsBar: View {
    let children: [FamilyMember]
    @Binding var selectedIndex: Int
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(children.indices, id: \.self) { index in
                    ChildTabButton(
                        child: children[index],
                        isSelected: selectedIndex == index
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedIndex = index
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Color(UIColor.secondarySystemGroupedBackground))
    }
}

struct ChildTabButton: View {
    let child: FamilyMember
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "person.circle.fill")
                    .font(.title3)
                Text(child.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isSelected ? Color.blue : Color.clear)
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color.clear : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Child Activity Content
struct ChildActivityContentView: View {
    let activityData: ChildActivityData
    @State private var isContentLoaded = false
    @State private var showHistory = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if showHistory {
                    // History view
                    historyView
                } else {
                    // Today's view (default)
                    todayView
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .opacity(isContentLoaded ? 1 : 0)
            .onAppear {
                withAnimation(.easeIn(duration: 0.3)) {
                    isContentLoaded = true
                }
            }
        }
    }
    
    private var todayView: some View {
        VStack(spacing: 12) {
            // Today's Social Time
            TodaySocialTimeCard(socialTime: activityData.todaySocialTime)
                .padding(.top, 8)
            
            // Study Monitor (6-10 PM)
            StudyTimeMonitor(studyTimeSocial: activityData.todayStudyTimeSocial)
            
            // Top 5 Apps
            if !activityData.todayTopApps.isEmpty {
                TopAppsSection(
                    apps: activityData.todayTopApps,
                    totalTime: activityData.todaySocialTime
                )
            }
            
            // View History Button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showHistory = true
                }
            }) {
                HStack {
                    Image(systemName: "calendar")
                        .font(.title3)
                    Text("View Weekly History")
                        .font(.headline)
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .foregroundColor(.white)
                .padding(20)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [.purple, .blue]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private var historyView: some View {
        VStack(spacing: 12) {
            // Back to Today Button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showHistory = false
                }
            }) {
                HStack {
                    Image(systemName: "arrow.left")
                        .font(.title3)
                    Text("Back to Today")
                        .font(.headline)
                    Spacer()
                }
                .foregroundColor(.blue)
                .padding(16)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(16)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.top, 8)
            
            if let weeklyHistory = activityData.weeklyHistory, !weeklyHistory.isEmpty {
                // Weekly Average Chart
                WeeklyActivityChart(dailyActivities: weeklyHistory)
                
                // Weekly History List
                WeeklyHistorySection(dailyActivities: weeklyHistory)
            } else {
                // Loading or no data state
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading weekly history...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(40)
            }
        }
    }
}

// MARK: - Today's Social Time Card
struct TodaySocialTimeCard: View {
    let socialTime: TimeInterval
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Today's Social Time")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    Text(formatDuration(socialTime))
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.pink)
                }
                
                Spacer()
                
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 54))
                    .foregroundColor(.pink.opacity(0.3))
            }
        }
        .padding(24)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

// MARK: - Study Time Monitor
struct StudyTimeMonitor: View {
    let studyTimeSocial: TimeInterval
    
    private var socialStudyHours: Double {
        studyTimeSocial / 3600.0
    }
    
    private var studyTarget: Double { 1.0 }
    
    private var socialPercentage: Double {
        min(socialStudyHours / studyTarget, 1.0)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .foregroundColor(.pink)
                Text("Study Time Monitoring")
                    .font(.headline)
                
                Spacer()
                
                Text("6-10 PM")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.pink.opacity(0.1))
                    .cornerRadius(8)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Today's Social Time During Study")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(Int(socialStudyHours))")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                            Text("h")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.secondary)
                            
                            Text("\(Int((socialStudyHours - floor(socialStudyHours)) * 60))")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                            Text("m")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Limit")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(Int(studyTarget))h")
                            .font(.headline)
                            .foregroundColor(.pink)
                    }
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 12)
                        
                        RoundedRectangle(cornerRadius: 6)
                            .fill(socialPercentage >= 1.0 ? Color.red : Color.pink)
                            .frame(width: geometry.size.width * socialPercentage, height: 12)
                            .animation(.easeInOut(duration: 0.5), value: socialPercentage)
                    }
                }
                .frame(height: 12)
                
                HStack {
                    Image(systemName: socialPercentage >= 1.0 ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(socialPercentage >= 1.0 ? .red : .green)
                    
                    Text(socialPercentage >= 1.0 ? "Limit exceeded! 📱" : "Within limit ✓")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(20)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

// MARK: - Weekly Activity Chart
struct WeeklyActivityChart: View {
    let dailyActivities: [DailyActivityData]
    @State private var selectedDayIndex: Int? = nil
    
    private var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter
    }
    
    private var maxHours: Double {
        let maxSeconds = dailyActivities.map { $0.totalSocialTime }.max() ?? 3600
        return max(maxSeconds / 3600.0, 1.0)
    }
    
    private var averageHours: Double {
        let totalSeconds = dailyActivities.reduce(0.0) { $0 + $1.totalSocialTime }
        return totalSeconds / 3600.0 / Double(dailyActivities.count)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Weekly Social Avg")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(Int(averageHours))")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                        Text("h")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        Text("\(Int((averageHours - floor(averageHours)) * 60))")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                        Text("m")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            
            GeometryReader { geometry in
                HStack(alignment: .bottom, spacing: 0) {
                    ForEach(dailyActivities.indices, id: \.self) { index in
                        let dayData = dailyActivities[index]
                        let dayHours = dayData.totalSocialTime / 3600.0
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.pink.opacity(0.7))
                                .frame(width: (geometry.size.width / CGFloat(dailyActivities.count)) - 8,
                                       height: max(8, CGFloat(dayHours / maxHours) * (geometry.size.height - 24)))
                            
                            Text(dayFormatter.string(from: dayData.date))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .frame(width: geometry.size.width / CGFloat(dailyActivities.count))
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedDayIndex = index
                                NotificationCenter.default.post(
                                    name: NSNotification.Name("HighlightDay"),
                                    object: index
                                )
                            }
                        }
                    }
                }
            }
            .frame(height: 100)
            
            Text("Tap bars to highlight day in history ↓")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(18)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

// MARK: - Weekly History Section
struct WeeklyHistorySection: View {
    let dailyActivities: [DailyActivityData]
    @State private var isExpanded = true
    @State private var highlightedDay: Int? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.purple)
                        .font(.title3)
                    Text("Weekly History")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.title3)
                        .foregroundColor(.purple)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(dailyActivities.indices, id: \.self) { index in
                        let dayData = dailyActivities[index]
                        DailyHistoryRow(
                            date: dayData.date,
                            socialTime: dayData.totalSocialTime / 3600.0,
                            studyTimeSocial: dayData.socialTimeDuringStudyHours / 3600.0,
                            isYesterday: index == 0,
                            isHighlighted: highlightedDay == index
                        )
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("HighlightDay"))) { notification in
            if let dayIndex = notification.object as? Int {
                withAnimation(.easeInOut(duration: 0.2)) {
                    highlightedDay = dayIndex
                    isExpanded = true
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        highlightedDay = nil
                    }
                }
            }
        }
    }
}

struct DailyHistoryRow: View {
    let date: Date
    let socialTime: Double
    let studyTimeSocial: Double
    let isYesterday: Bool
    let isHighlighted: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 2) {
                if isYesterday {
                    Text("Yesterday")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.purple)
                        .cornerRadius(6)
                }
                
                Text(dateFormatter.string(from: date))
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(isHighlighted ? .pink : (isYesterday ? .purple : .primary))
            }
            .frame(width: 60)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.title3)
                        .foregroundColor(.pink)
                    
                    Text("Social:")
                        .font(.callout)
                        .foregroundColor(.secondary)
                    
                    Text(formatTime(socialTime))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.pink)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.callout)
                            .foregroundColor(.orange)
                        Text(formatTime(studyTimeSocial))
                            .font(.callout)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
        .padding(12)
        .background(isHighlighted ? Color.pink.opacity(0.15) : Color(UIColor.tertiarySystemGroupedBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isHighlighted ? Color.pink : Color.clear, lineWidth: 2)
        )
        .cornerRadius(12)
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }
    
    private func formatTime(_ hours: Double) -> String {
        let h = Int(hours)
        let m = Int((hours - floor(hours)) * 60)
        if h > 0 {
            return "\(h)h \(m)m"
        } else {
            return "\(m)m"
        }
    }
}

// MARK: - Top Apps Section
struct TopAppsSection: View {
    let apps: [AppUsageInfo]
    let totalTime: TimeInterval
    @State private var selectedApp: AppUsageInfo? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.orange)
                Text("Most Used Apps")
                    .font(.headline)
            }
            
            VStack(spacing: 12) {
                ForEach(Array(apps.enumerated()), id: \.element.id) { index, app in
                    TopAppCard(
                        app: app,
                        rank: index + 1,
                        percentage: totalTime > 0 ? app.duration / totalTime : 0
                    )
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedApp = app
                        }
                    }
                }
            }
            
            // App Detail Sheet
            if let app = selectedApp {
                AppDetailView(app: app, isPresented: Binding(
                    get: { selectedApp != nil },
                    set: { if !$0 { selectedApp = nil } }
                ))
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

struct TopAppCard: View {
    let app: AppUsageInfo
    let rank: Int
    let percentage: Double
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(rankColor)
                    .frame(width: 36, height: 36)
                
                Text("\(rank)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(app.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.caption2)
                    Text(formatDuration(app.duration))
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(percentage * 100))%")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(rankColor)
            }
        }
        .padding(12)
        .background(Color(UIColor.tertiarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    private var rankColor: Color {
        switch rank {
        case 1: return .orange
        case 2: return .blue
        case 3: return .purple
        case 4: return .green
        case 5: return .pink
        default: return .gray
        }
    }
}

// MARK: - Helper Functions
private func formatDuration(_ duration: TimeInterval) -> String {
    let hours = Int(duration) / 3600
    let minutes = (Int(duration) % 3600) / 60
    let seconds = Int(duration) % 60
    
    if hours > 0 {
        return "\(hours)h \(minutes)m"
    } else if minutes > 0 {
        return "\(minutes)m"
    } else if seconds > 0 {
        return "\(seconds)s"
    } else {
        return "< 1s"
    }
}

// MARK: - App Detail View
struct AppDetailView: View {
    let app: AppUsageInfo
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Overlay background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation {
                        isPresented = false
                    }
                }
            
            // Detail Card
            VStack(spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(app.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Today's Usage Timeline")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation {
                            isPresented = false
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                }
                
                // Total Time Card
                VStack(spacing: 8) {
                    Text("Total Time Today")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatDuration(app.duration))
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.blue)
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
                
                // Real data we have
                VStack(alignment: .leading, spacing: 12) {
                    Text("Available Data")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundColor(.blue)
                        Text("Total time from midnight to now")
                        Spacer()
                        Text(formatDuration(app.duration))
                            .fontWeight(.semibold)
                    }
                    .padding(12)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(8)
                }
                .padding(16)
                .background(Color(UIColor.tertiarySystemGroupedBackground))
                .cornerRadius(12)
                
                // Limitation notice
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.orange)
                        Text("Data Limitation")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    
                    Text("iOS Screen Time API only provides daily totals for third-party apps. Hour-by-hour usage data is not available. Apple's own Screen Time has access to more detailed system-level data.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
            }
            .padding(24)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(20)
            .padding(.horizontal, 20)
            .shadow(color: .black.opacity(0.3), radius: 20)
        }
    }
}

// TimelineView removed - iOS Screen Time API doesn't provide hour-by-hour data
// Only daily totals are available to third-party apps
