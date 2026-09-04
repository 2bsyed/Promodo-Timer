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
                    .fill(Color.black.opacity(0.2))
                    .background(VisualEffectView(material: .popover, blendingMode: .withinWindow).opacity(0.85))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.white.opacity(0.2), Color.white.opacity(0.05)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: Color.black.opacity(0.40), radius: 8, x: 0, y: 4)
    }
}

struct HistoryView: View {
    @ObservedObject var historyManager = TimerHistoryManager.shared
    @State private var isCloseHovered = false
    
    private let accentColor = Color(red: 241/255, green: 152/255, blue: 70/255)
    private let monthlyRingColor = Color(red: 57/255, green: 211/255, blue: 83/255) // GitHub bright green
    
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
                
                // GitHub Grid Card
                GitHubGridCardView()
                
                // Lifetime Stats Card
                LifetimeStatsCardView()
                
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
    
    // MARK: - GitHub Grid Card Component
    @ViewBuilder
    private func GitHubGridCardView() -> some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let columns = 15
        let totalDays = columns * 7
        
        let weekday = calendar.component(.weekday, from: today)
        let daysToSubtract = (weekday - 1) + ((columns - 1) * 7)
        let startSunday = calendar.date(byAdding: .day, value: -daysToSubtract, to: today)!
        
        let sessionsMap = historyManager.getRecentSessionsMap(days: daysToSubtract + 7)
        
        let gridRows = Array(repeating: GridItem(.fixed(16), spacing: 4), count: 7)
        
        let dates: [Date] = (0..<totalDays).map { i in
            calendar.date(byAdding: .day, value: i, to: startSunday)!
        }
        
        HistoryCard {
            // Container with same explicit padding as the Weekly Card's content
            // Weekly content: 44 (header) + 8 (spacing) + 95 (chart) = 147
            // Grid content: (16 * 7) + (4 * 6) = 136
            // We use a frame of 147 so the cards match exactly in size.
            VStack {
                Spacer(minLength: 0)
                LazyHGrid(rows: gridRows, spacing: 4) {
                    ForEach(0..<dates.count, id: \.self) { idx in
                        let date = dates[idx]
                        let sessions = sessionsMap[date] ?? 0
                        
                        RoundedRectangle(cornerRadius: 3.0, style: .continuous)
                            .fill(date > today ? githubColor(for: 0) : githubColor(for: sessions))
                            .frame(width: 16, height: 16)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(height: 147)
        }
    }
    
    // MARK: - GitHub Contribution Color
    private func githubColor(for sessions: Int) -> Color {
        switch sessions {
        case 0: return Color(red: 22/255, green: 27/255, blue: 34/255).opacity(0.8) // Dark base
        case 1: return Color(red: 14/255, green: 68/255, blue: 41/255)
        case 2: return Color(red: 0/255, green: 109/255, blue: 50/255)
        case 3: return Color(red: 38/255, green: 166/255, blue: 65/255)
        default: return Color(red: 57/255, green: 211/255, blue: 83/255)
        }
    }
    
    // MARK: - Lifetime Stats Card Component
    @ViewBuilder
    private func LifetimeStatsCardView() -> some View {
        HistoryCard {
            HStack(spacing: 0) {
                // Streak
                VStack(spacing: 2) {
                    Text("Streak")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.4))
                    Text("\(historyManager.getCurrentStreak())d")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(monthlyRingColor)
                }
                .frame(maxWidth: .infinity)
                
                Divider()
                    .background(Color.white.opacity(0.1))
                    .frame(height: 30)
                
                // Total Time
                VStack(spacing: 2) {
                    Text("Total Time")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.4))
                    Text(formatDuration(seconds: historyManager.getTotalTimeAllTime()))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                }
                .frame(maxWidth: .infinity)
                
                Divider()
                    .background(Color.white.opacity(0.1))
                    .frame(height: 30)
                
                // Total Sessions
                VStack(spacing: 2) {
                    Text("Sessions")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.4))
                    Text("\(historyManager.getTotalSessionsAllTime())")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(accentColor)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 4)
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
