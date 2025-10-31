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
            
            // Process segments
            for await segment in datum.activitySegments {
                let segmentDate = calendar.startOfDay(for: segment.dateInterval.start)
                let isToday = calendar.isDate(segmentDate, inSameDayAs: today)
                
                var socialTimeThisSegment: TimeInterval = 0
                var studyTimeThisSegment: TimeInterval = 0
                var appsThisSegment: [String: (TimeInterval, String)] = [:]
                
                for await category in segment.categories {
                    let categoryName = category.category.localizedDisplayName ?? "Other"
                    let isSocial = categoryName.lowercased().contains("social") ||
                                  categoryName.lowercased().contains("entertainment") ||
                                  categoryName.lowercased().contains("networking")
                    
                    if isSocial {
                        socialTimeThisSegment += category.totalActivityDuration
                        
                        for await app in category.applications {
                            let appName = app.application.localizedDisplayName ?? "Unknown App"
                            let appDuration = app.totalActivityDuration
                            let tokenString = "\(app.application.token.hashValue)"
                            
                            if let existing = appsThisSegment[appName] {
                                appsThisSegment[appName] = (existing.0 + appDuration, existing.1)
                            } else {
                                appsThisSegment[appName] = (appDuration, tokenString)
                            }
                            
                            // Estimate study hours (6-10 PM ≈ 17% of day)
                            studyTimeThisSegment += appDuration * 0.17
                        }
                    }
                }
                
                if isToday {
                    todaySocialTime += socialTimeThisSegment
                    todayStudyTimeSocial += studyTimeThisSegment
                    for (appName, appData) in appsThisSegment {
                        if let existing = todayApps[appName] {
                            todayApps[appName] = (existing.0 + appData.0, existing.1)
                        } else {
                            todayApps[appName] = appData
                        }
                    }
                } else {
                    // Store historical data
                    if var existing = weeklyData[segmentDate] {
                        existing.socialTime += socialTimeThisSegment
                        existing.studyTime += studyTimeThisSegment
                        for (appName, appData) in appsThisSegment {
                            if let existingApp = existing.apps[appName] {
                                existing.apps[appName] = (existingApp.0 + appData.0, existingApp.1)
                            } else {
                                existing.apps[appName] = appData
                            }
                        }
                        weeklyData[segmentDate] = existing
                    } else {
                        weeklyData[segmentDate] = (socialTimeThisSegment, studyTimeThisSegment, appsThisSegment)
                    }
                }
            }
            
            let topApps = todayApps.map {
                AppUsageInfo(name: $0.key, duration: $0.value.0, token: $0.value.1)
            }.sorted { $0.duration > $1.duration }
            .prefix(5).map { $0 }
            
            // Create weekly history array
            var weeklyHistory: [DailyActivityData] = []
            for i in 1...7 {
                let date = calendar.date(byAdding: .day, value: -i, to: today)!
                let dayStart = calendar.startOfDay(for: date)
                
                if let dayData = weeklyData[dayStart] {
                    let apps = dayData.apps.map {
                        AppUsageInfo(name: $0.key, duration: $0.value.0, token: $0.value.1)
                    }.sorted { $0.duration > $1.duration }
                    
                    weeklyHistory.append(DailyActivityData(
                        date: dayStart,
                        totalSocialTime: dayData.socialTime,
                        socialTimeDuringStudyHours: dayData.studyTime,
                        apps: apps
                    ))
                } else {
                    weeklyHistory.append(DailyActivityData(
                        date: dayStart,
                        totalSocialTime: 0,
                        socialTimeDuringStudyHours: 0,
                        apps: []
                    ))
                }
            }
            weeklyHistory = weeklyHistory.reversed()
            
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
                weeklyHistory: weeklyHistory.isEmpty ? nil : weeklyHistory
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
                    // Today's view (default - fast)
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
            if activityData.weeklyHistory != nil {
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
            
            if let weeklyHistory = activityData.weeklyHistory {
                // Weekly Average Chart
                WeeklyActivityChart(dailyActivities: weeklyHistory)
                
                // Weekly History List
                WeeklyHistorySection(dailyActivities: weeklyHistory)
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
                            isYesterday: index == dailyActivities.count - 1,
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
                Text(dateFormatter.string(from: date))
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(isHighlighted ? .pink : (isYesterday ? .purple : .primary))
            }
            .frame(width: 60)
            
            VStack(alignment: .leading, spacing: 8) {
                if isYesterday {
                    Text("Yesterday")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.purple)
                        .cornerRadius(8)
                }
                
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
                }
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
