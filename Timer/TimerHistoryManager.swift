import Foundation

struct SessionRecord: Codable, Identifiable {
    var id: UUID = UUID()
    let timestamp: Date
    let durationMinutes: Double
    
    // Backward compatibility for previously saved files
    var sessionsCount: Int? = nil
    
    // Dynamically calculate sessions using the 25-minute floor rule
    var calculatedSessions: Int {
        if let saved = sessionsCount {
            return saved
        }
        if durationMinutes < 25.0 {
            return 0
        }
        return Int(durationMinutes) / 25
    }
}

struct DailyFocus: Identifiable {
    var id = UUID()
    let date: Date
    let label: String
    let durationSeconds: Double
}

class TimerHistoryManager: ObservableObject {
    static let shared = TimerHistoryManager()
    
    @Published var history: [SessionRecord] = []
    
    private init() {
        loadHistory()
    }
    
    private var fileURL: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".pomodoro_timer_history.json")
    }
    
    func loadHistory() {
        let path = fileURL
        if FileManager.default.fileExists(atPath: path.path) {
            do {
                let data = try Data(contentsOf: path)
                let decoder = JSONDecoder()
                let decoded = try decoder.decode([SessionRecord].self, from: data)
                DispatchQueue.main.async {
                    self.history = decoded
                }
            } catch {
                print("Failed to load history: \(error)")
                DispatchQueue.main.async {
                    self.history = []
                }
            }
        } else {
            DispatchQueue.main.async {
                self.history = []
            }
        }
    }
    
    func saveHistory() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(history)
            try data.write(to: fileURL, options: .atomic)
            print("Saved history to \(fileURL.path)")
        } catch {
            print("Failed to save history: \(error)")
        }
    }
    
    func recordSession(durationMinutes: Double) {
        // Record all finished durations (even 1s) to support detailed Screen Time metrics
        let record = SessionRecord(id: UUID(), timestamp: Date(), durationMinutes: durationMinutes)
        DispatchQueue.main.async {
            self.history.append(record)
            self.saveHistory()
        }
    }
    
    // Weekly metrics
    func getWeeklyFocus() -> [DailyFocus] {
        var result: [DailyFocus] = []
        let calendar = Calendar.current
        let now = Date()
        
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEEE" // Single letter abbreviation (e.g. S, M, T, W, T, F, S)
        
        for i in (0...6).reversed() {
            guard let dayDate = calendar.date(byAdding: .day, value: -i, to: now) else { continue }
            
            let startOfDay = calendar.startOfDay(for: dayDate)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            
            let dailySeconds = history
                .filter { $0.timestamp >= startOfDay && $0.timestamp < endOfDay }
                .reduce(0.0) { $0 + ($1.durationMinutes * 60.0) }
                
            let dayLabel = formatter.string(from: dayDate)
            result.append(DailyFocus(date: dayDate, label: dayLabel, durationSeconds: dailySeconds))
        }
        return result
    }
    
    var todayFocusSeconds: Double {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        return history
            .filter { $0.timestamp >= today && $0.timestamp < tomorrow }
            .reduce(0.0) { $0 + ($1.durationMinutes * 60.0) }
    }
    
    var weeklyAverageSeconds: Double {
        let focus = getWeeklyFocus()
        let total = focus.reduce(0.0) { $0 + $1.durationSeconds }
        return total / 7.0
    }
    
    var weeklyTrendPercentage: Double? {
        let calendar = Calendar.current
        let now = Date()
        
        // Current week (last 7 days)
        var currentWeekSeconds = 0.0
        for i in 0...6 {
            guard let dayDate = calendar.date(byAdding: .day, value: -i, to: now) else { continue }
            let startOfDay = calendar.startOfDay(for: dayDate)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            currentWeekSeconds += history
                .filter { $0.timestamp >= startOfDay && $0.timestamp < endOfDay }
                .reduce(0.0) { $0 + ($1.durationMinutes * 60.0) }
        }
        
        // Previous week (days 7 to 13 ago)
        var previousWeekSeconds = 0.0
        for i in 7...13 {
            guard let dayDate = calendar.date(byAdding: .day, value: -i, to: now) else { continue }
            let startOfDay = calendar.startOfDay(for: dayDate)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            previousWeekSeconds += history
                .filter { $0.timestamp >= startOfDay && $0.timestamp < endOfDay }
                .reduce(0.0) { $0 + ($1.durationMinutes * 60.0) }
        }
        
        if previousWeekSeconds == 0.0 {
            if currentWeekSeconds == 0.0 {
                return 0.0
            }
            return 100.0
        }
        
        return ((currentWeekSeconds - previousWeekSeconds) / previousWeekSeconds) * 100.0
    }
    
    // Monthly metrics
    func getMonthlyAverageSessions(for monthDate: Date) -> Double {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: monthDate)
        guard let startOfMonth = calendar.date(from: components) else { return 1.0 }
        guard let range = calendar.range(of: .day, in: .month, for: startOfMonth) else { return 1.0 }
        let totalDays = range.count
        
        let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
        
        let monthSessions = history.filter { $0.timestamp >= startOfMonth && $0.timestamp < endOfMonth }
        let totalSessions = monthSessions.reduce(0) { $0 + $1.calculatedSessions }
        
        let now = Date()
        let elapsedDays: Int
        if calendar.isDate(now, equalTo: monthDate, toGranularity: .month) {
            elapsedDays = calendar.component(.day, from: now)
        } else if now < startOfMonth {
            elapsedDays = 1
        } else {
            elapsedDays = totalDays
        }
        
        let avg = Double(totalSessions) / Double(max(1, elapsedDays))
        return avg >= 1.0 ? avg : 1.0
    }
    
    func getSessions(for date: Date) -> Int {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        return history
            .filter { $0.timestamp >= startOfDay && $0.timestamp < endOfDay }
            .reduce(0) { $0 + $1.calculatedSessions }
    }
    
    func getTotalSessions(for monthDate: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: monthDate)
        guard let startOfMonth = calendar.date(from: components) else { return 0 }
        let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
        
        return history
            .filter { $0.timestamp >= startOfMonth && $0.timestamp < endOfMonth }
            .reduce(0) { $0 + $1.calculatedSessions }
    }
    
    func getCurrentStreak() -> Int {
        let calendar = Calendar.current
        let now = Date()
        
        let sessionDates = Set(history.compactMap { record -> Date? in
            guard record.calculatedSessions > 0 else { return nil }
            return calendar.startOfDay(for: record.timestamp)
        }).sorted(by: >)
        
        if sessionDates.isEmpty {
            return 0
        }
        
        let today = calendar.startOfDay(for: now)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return 0 }
        
        var currentCheckDate: Date
        if sessionDates.contains(today) {
            currentCheckDate = today
        } else if sessionDates.contains(yesterday) {
            currentCheckDate = yesterday
        } else {
            return 0
        }
        
        var streak = 0
        while true {
            if sessionDates.contains(currentCheckDate) {
                streak += 1
                guard let prevDate = calendar.date(byAdding: .day, value: -1, to: currentCheckDate) else { break }
                currentCheckDate = prevDate
            } else {
                break
            }
        }
        
        return streak
    }
}
