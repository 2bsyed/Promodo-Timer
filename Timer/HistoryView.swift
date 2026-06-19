import SwiftUI
import AppKit

// A bridge to NSVisualEffectView for native macOS frosted glass effect
struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// Apple Fitness Style activity ring (neon red/pink from the Apple Fitness screenshot)
struct RingView: View {
    let progress: Double
    let size: CGFloat
    
    private let ringColor = Color(red: 255/255, green: 12/255, blue: 71/255)
    
    var body: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(ringColor.opacity(0.14), lineWidth: 3.0)
            
            // Progress arc
            Circle()
                .trim(from: 0.0, to: CGFloat(min(progress, 1.0)))
                .stroke(
                    ringColor,
                    style: StrokeStyle(lineWidth: 3.0, lineCap: .round)
                )
                .rotationEffect(Angle(degrees: -90))
            
            // Overlapping segment for >100% completion
            if progress > 1.0 {
                Circle()
                    .trim(from: 0.0, to: CGFloat(min(progress - 1.0, 1.0)))
                    .stroke(
                        Color(red: 255/255, green: 80/255, blue: 120/255),
                        style: StrokeStyle(lineWidth: 3.0, lineCap: .round)
                    )
                    .rotationEffect(Angle(degrees: -90))
                    .shadow(color: Color.black.opacity(0.35), radius: 1.5, x: 0, y: 0.5)
            }
        }
        .frame(width: size, height: size)
    }
}

// Custom Glassmorphic Card Wrapper with 28pt rounded corners and subtle shadow
struct HistoryCard<Content: View>: View {
    var content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.black.opacity(0.40))
                    .background(VisualEffectView(material: .hudWindow, blendingMode: .withinWindow).opacity(0.85))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: Color.black.opacity(0.40), radius: 8, x: 0, y: 4)
    }
}

struct HistoryView: View {
    @ObservedObject var historyManager = TimerHistoryManager.shared
    @State private var activeMonthDate = Date()
    @State private var isCloseHovered = false
    
    private let accentColor = Color(red: 241/255, green: 152/255, blue: 70/255)
    private let monthlyRingColor = Color(red: 255/255, green: 12/255, blue: 71/255)
    
    var body: some View {
        ZStack {
            // 1. Pitch-black base background
            Color.black
                .ignoresSafeArea()
            
            // 2. Ambient background lights for depth
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.06))
                    .frame(width: 240, height: 240)
                    .blur(radius: 75)
                    .offset(x: -110, y: -150)
                
                Circle()
                    .fill(accentColor.opacity(0.03))
                    .frame(width: 290, height: 290)
                    .blur(radius: 90)
                    .offset(x: 120, y: 140)
            }
            .allowsHitTesting(false)
            
            // 3. Subtle Vignette behind the content (keeps text 100% sharp and readable!)
            RadialGradient(
                gradient: Gradient(stops: [
                    .init(color: .clear, location: 0.60),
                    .init(color: Color.black.opacity(0.70), location: 1.0)
                ]),
                center: .center,
                startRadius: 130,
                endRadius: 360
            )
            .allowsHitTesting(false)
            
            // 4. Compact Vertical Stack Layout with 12pt gaps (No Scrolling)
            VStack(alignment: .leading, spacing: 12) {
                // Top close button with exact same spacing from left and top (symmetrical 8pt padding)
                HStack {
                    Button(action: {
                        for window in NSApplication.shared.windows {
                            if window.frameAutosaveName == "HistoryWindow" {
                                window.close()
                                break
                            }
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white.opacity(isCloseHovered ? 0.9 : 0.4))
                            .frame(width: 24, height: 24)
                            .background(Color.white.opacity(isCloseHovered ? 0.12 : 0.05))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .onHover { hovering in
                        isCloseHovered = hovering
                    }
                    .padding(.leading, 8)
                    .padding(.top, 8)
                    Spacer()
                }
                .frame(height: 32)
                
                // Weekly Card
                WeeklyCardView()
                
                // Monthly Card
                MonthlyCardView()
                
                Spacer(minLength: 0)
            }
            .padding(18) // Generous 18pt padding all around
        }
        .frame(width: 360, height: 590)
        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous)) // Nested 36pt corner radius (perfect geometry with 28pt cards)
    }
    
    // MARK: - Weekly Card Component
    @ViewBuilder
    private func WeeklyCardView() -> some View {
        let weeklyFocus = historyManager.getWeeklyFocus()
        let avgSeconds = historyManager.weeklyAverageSeconds
        let trend = historyManager.weeklyTrendPercentage
        let todaySeconds = historyManager.todayFocusSeconds
        
        return HistoryCard {
            VStack(alignment: .leading, spacing: 8) {
                // Header details: Today on left, Daily Average on right
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Today")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.4))
                        
                        Text(formatDuration(seconds: todaySeconds))
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundColor(accentColor)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Daily Average")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.4))
                        
                        Text(formatDuration(seconds: avgSeconds))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.4))
                        
                        if let trendVal = trend {
                            HStack(spacing: 3) {
                                Image(systemName: trendVal >= 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                                    .font(.system(size: 10, weight: .semibold))
                                Text(String(format: "%.0f%% from last week", abs(trendVal)))
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                            }
                            .foregroundColor(trendVal >= 0 ? .green : .red)
                        }
                    }
                }
                
                // Weekly Bar Chart
                WeeklyBarChartView(focusData: weeklyFocus, averageSeconds: avgSeconds)
            }
        }
    }
    
    // MARK: - Monthly Card Component
    @ViewBuilder
    private func MonthlyCardView() -> some View {
        let calendar = Calendar.current
        let cells = generateCalendarCells(for: activeMonthDate)
        let monthlyAverage = historyManager.getMonthlyAverageSessions(for: activeMonthDate)
        let totalSessions = historyManager.getTotalSessions(for: activeMonthDate)
        let currentStreak = historyManager.getCurrentStreak()
        
        let isCurrentMonth = calendar.isDate(activeMonthDate, equalTo: Date(), toGranularity: .month)
        let todayWeekday = calendar.component(.weekday, from: Date())
        let todayIndex = todayWeekday % 7
        
        let weekDays = ["S", "S", "M", "T", "W", "T", "F"]
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
        
        HistoryCard {
            VStack(alignment: .leading, spacing: 8) {
                // Month Navigation Header
                HStack {
                    Text(monthYearString(from: activeMonthDate))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(accentColor)
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Button(action: {
                            if let prevMonth = calendar.date(byAdding: .month, value: -1, to: activeMonthDate) {
                                activeMonthDate = prevMonth
                            }
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white.opacity(0.6))
                                .frame(width: 22, height: 22)
                                .background(Color.white.opacity(0.06))
                                .clipShape(Circle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: {
                            if let nextMonth = calendar.date(byAdding: .month, value: 1, to: activeMonthDate) {
                                activeMonthDate = nextMonth
                            }
                        }) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white.opacity(0.6))
                                .frame(width: 22, height: 22)
                                .background(Color.white.opacity(0.06))
                                .clipShape(Circle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                // Days of week header row
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { i in
                        let isTodayHeader = isCurrentMonth && (i == todayIndex)
                        Text(weekDays[i])
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundColor(isTodayHeader ? .white : .white.opacity(0.3))
                            .frame(width: 18, height: 18)
                            .background(isTodayHeader ? monthlyRingColor : Color.clear)
                            .clipShape(Circle())
                            .frame(maxWidth: .infinity)
                    }
                }
                
                // Grid of dates with Apple Fitness rings
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(0..<cells.count, id: \.self) { idx in
                        if let date = cells[idx] {
                            let dayNum = calendar.component(.day, from: date)
                            let sessions = historyManager.getSessions(for: date)
                            let progress = monthlyAverage > 0 ? Double(sessions) / monthlyAverage : 0.0
                            let isToday = calendar.isDateInToday(date)
                            
                            ZStack {
                                // Fitness progress ring
                                RingView(progress: progress, size: 22)
                                

                                
                                // Day digit
                                Text("\(dayNum)")
                                    .font(.system(size: 9, weight: isToday ? .bold : .medium, design: .rounded))
                                    .foregroundColor(isToday ? monthlyRingColor : (sessions > 0 ? .white : .white.opacity(0.5)))
                            }
                            .frame(height: 28)
                        } else {
                            Color.clear
                                .frame(height: 28)
                        }
                    }
                }
                
                Divider()
                    .background(Color.white.opacity(0.06))
                    .padding(.vertical, 1)
                
                // Footer metrics
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(totalSessions)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(accentColor)
                        Text("Total Sessions")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 20))
                            .foregroundColor(monthlyRingColor)
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(currentStreak) \(currentStreak == 1 ? "day" : "days")")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(accentColor)
                            Text("Current Streak")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.4))
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private func formatDuration(seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
    
    private func generateCalendarCells(for monthDate: Date) -> [Date?] {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: monthDate)
        guard let startOfMonth = calendar.date(from: components) else { return [] }
        guard let range = calendar.range(of: .day, in: .month, for: startOfMonth) else { return [] }
        let numberOfDays = range.count
        
        let weekdayOfFirst = calendar.component(.weekday, from: startOfMonth)
        let offset = weekdayOfFirst % 7
        
        var cells: [Date?] = []
        for _ in 0..<offset {
            cells.append(nil)
        }
        for day in 1...numberOfDays {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                cells.append(date)
            }
        }
        return cells
    }
}

// MARK: - Custom Weekly Bar Chart
struct WeeklyBarChartView: View {
    let focusData: [DailyFocus]
    let averageSeconds: Double
    
    private let barColor = Color(red: 0/255, green: 210/255, blue: 255/255)
    
    var body: some View {
        let maxSeconds = focusData.map { $0.durationSeconds }.max() ?? 0.0
        let maxHours = maxSeconds / 3600.0
        let yAxisMax = max(4.0, ceil(maxHours / 2.0) * 2.0)
        let averageHours = averageSeconds / 3600.0
        
        GeometryReader { geo in
            let chartWidth = geo.size.width - 30
            let chartHeight = geo.size.height - 18
            let colWidth = chartWidth / 7.0
            let barWidth: CGFloat = 22
            
            ZStack(alignment: .topLeading) {
                // Horizontal reference grid lines (5 lines total)
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: chartWidth, y: 0))
                    
                    path.move(to: CGPoint(x: 0, y: chartHeight * 0.25))
                    path.addLine(to: CGPoint(x: chartWidth, y: chartHeight * 0.25))
                    
                    path.move(to: CGPoint(x: 0, y: chartHeight * 0.5))
                    path.addLine(to: CGPoint(x: chartWidth, y: chartHeight * 0.5))
                    
                    path.move(to: CGPoint(x: 0, y: chartHeight * 0.75))
                    path.addLine(to: CGPoint(x: chartWidth, y: chartHeight * 0.75))
                    
                    path.move(to: CGPoint(x: 0, y: chartHeight))
                    path.addLine(to: CGPoint(x: chartWidth, y: chartHeight))
                }
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                
                // Vertical separating dotted lines (boundaries between columns, exactly 8 lines for 7 boxes)
                Path { path in
                    for i in 0...7 {
                        let x = CGFloat(i) * colWidth
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: chartHeight))
                    }
                }
                .stroke(Color.white.opacity(0.08), style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [2, 4]))
                
                // Dashed green average line
                if yAxisMax > 0 {
                    let avgY = chartHeight * CGFloat(1.0 - (averageHours / yAxisMax))
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: avgY))
                        path.addLine(to: CGPoint(x: chartWidth, y: avgY))
                    }
                    .stroke(Color.green.opacity(0.85), style: StrokeStyle(lineWidth: 1.2, lineCap: .round, dash: [4, 3]))
                    
                    // Position "avg" label outside the chart, aligned in the y-axis labels column
                    Text("avg")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                        .frame(width: 24, alignment: .leading)
                        .position(x: chartWidth + 4 + 12, y: avgY)
                }
                
                // 7 Days bars (each inside its own column box)
                HStack(alignment: .bottom, spacing: 0) {
                    ForEach(focusData) { day in
                        let dayHours = day.durationSeconds / 3600.0
                        let barHeight = yAxisMax > 0 ? chartHeight * CGFloat(dayHours / yAxisMax) : 0
                        
                        VStack(spacing: 4) {
                            Spacer()
                            
                            if day.durationSeconds > 0 {
                                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                                    .fill(barColor)
                                    .frame(width: barWidth, height: max(barHeight, 2.0))
                            } else {
                                Color.clear
                                    .frame(width: barWidth, height: 2.0)
                            }
                            
                            Text(day.label)
                                .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.35))
                                .padding(.leading, 5)
                                .frame(width: colWidth, alignment: .leading)
                        }
                        .frame(width: colWidth)
                    }
                }
                .frame(width: chartWidth, height: geo.size.height)
                
                // Y-Axis Labels
                VStack(alignment: .leading, spacing: 0) {
                    Text(String(format: "%.0fh", yAxisMax))
                        .font(.system(size: 8, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.3))
                    Spacer()
                    Text(String(format: "%.0fh", yAxisMax / 2))
                        .font(.system(size: 8, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.3))
                    Spacer()
                    Text("0")
                        .font(.system(size: 8, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.3))
                }
                .frame(height: chartHeight)
                .offset(x: chartWidth + 4)
            }
        }
        .frame(height: 95)
        .padding(.top, 4)
    }
}
