import Foundation
import FoundationModels

@Generable
struct ParsedDateTime {
    @Guide(description: "A short human-readable label for this date, e.g. 'tomorrow morning', 'next Tuesday at 3 pm'")
    var label: String

    @Guide(description: "Year as four digits, e.g. 2026")
    var year: Int

    @Guide(description: "Month 1-12", .range(1...12))
    var month: Int

    @Guide(description: "Day of month 1-31", .range(1...31))
    var day: Int

    @Guide(description: "Hour in 24-hour format 0-23", .range(0...23))
    var hour: Int

    @Guide(description: "Minute 0-59", .range(0...59))
    var minute: Int
}

@MainActor
public class NaturalLanguageDateParser {

    public init() {}

    // MARK: - Public API

    public func suggestions(for input: String) -> [TimeSuggestion] {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if trimmed.isEmpty {
            return defaultSuggestions()
        }

        var results: [TimeSuggestion] = []

        results += parseNumber(trimmed)
        results += parseTimeExpression(trimmed)
        results += matchKeywords(trimmed)
        results += parseDuration(trimmed)
        results += parseDayName(trimmed)
        results += parseWithDataDetector(input)

        // Deduplicate by label
        var seen = Set<String>()
        results = results.filter { seen.insert($0.label).inserted }

        return Array(results.prefix(6))
    }

    public func defaultSuggestions() -> [TimeSuggestion] {
        let now = Date()
        let calendar = Calendar.current

        let inOneHour = now.addingTimeInterval(3600)
        let inThreeHours = now.addingTimeInterval(3 * 3600)

        // Tonight 9 PM
        var tonightComp = calendar.dateComponents([.year, .month, .day], from: now)
        tonightComp.hour = 21
        tonightComp.minute = 0
        let tonightRaw = calendar.date(from: tonightComp)!
        let tonight = tonightRaw > now ? tonightRaw : tonightRaw.addingTimeInterval(86400)

        // Tomorrow 9 AM
        let tomorrowDay = calendar.date(byAdding: .day, value: 1, to: now)!
        var tomorrowComp = calendar.dateComponents([.year, .month, .day], from: tomorrowDay)
        tomorrowComp.hour = 9
        tomorrowComp.minute = 0
        let tomorrowDate = calendar.date(from: tomorrowComp)!

        // This Weekend - Saturday noon
        let weekendDate = nextSaturday(at: 12, minute: 0)

        // Someday - random time in the next 1-7 days
        let somedayDate = generateSomedayDate()

        return [
            TimeSuggestion(label: "In an hour", date: inOneHour, formattedDate: formatDate(inOneHour)),
            TimeSuggestion(label: "In 3 hours", date: inThreeHours, formattedDate: formatDate(inThreeHours)),
            TimeSuggestion(label: "Tonight", date: tonight, formattedDate: formatDate(tonight)),
            TimeSuggestion(label: "Tomorrow", date: tomorrowDate, formattedDate: formatDate(tomorrowDate)),
            TimeSuggestion(label: "This Weekend", date: weekendDate, formattedDate: formatDate(weekendDate)),
            TimeSuggestion(label: "Someday", date: somedayDate, formattedDate: "\u{00AF}\\_(ツ)_/\u{00AF}"),
            TimeSuggestion(label: "Never", date: .distantFuture, formattedDate: "\u{00AF}\\_(ツ)_/\u{00AF}", neverNotify: true),
        ]
    }

    // MARK: - Bare Number ("4", "eight")

    private func parseNumber(_ input: String) -> [TimeSuggestion] {
        guard let n = extractNumber(input), n > 0, n <= 999 else { return [] }

        // Only match bare numbers, not "4 hours" (that's parseDuration)
        if input.contains(" ") { return [] }

        let now = Date()

        let inMinutes = now.addingTimeInterval(Double(n) * 60)
        let inHours = now.addingTimeInterval(Double(n) * 3600)
        let inWeekdays = addWeekdays(n, from: now)

        return [
            TimeSuggestion(
                label: "in \(n) minute\(n == 1 ? "" : "s")",
                date: inMinutes,
                formattedDate: formatDate(inMinutes)
            ),
            TimeSuggestion(
                label: "in \(n) hour\(n == 1 ? "" : "s")",
                date: inHours,
                formattedDate: formatDate(inHours)
            ),
            TimeSuggestion(
                label: "in \(n) weekday\(n == 1 ? "" : "s")",
                date: inWeekdays,
                formattedDate: formatDate(inWeekdays)
            ),
        ]
    }

    // MARK: - Time Expression ("9pm", "3:30pm", "21:00")

    private func parseTimeExpression(_ input: String) -> [TimeSuggestion] {
        let cleaned = input.replacingOccurrences(of: " ", with: "")

        var hour: Int?
        var minute = 0
        var isPM: Bool?

        if cleaned.hasSuffix("am") {
            isPM = false
            let numPart = String(cleaned.dropLast(2))
            let parsed = splitHourMinute(numPart)
            hour = parsed.0
            minute = parsed.1
        } else if cleaned.hasSuffix("pm") {
            isPM = true
            let numPart = String(cleaned.dropLast(2))
            let parsed = splitHourMinute(numPart)
            hour = parsed.0
            minute = parsed.1
        } else if cleaned.contains(":"), cleaned.count <= 5 {
            let parsed = splitHourMinute(cleaned)
            hour = parsed.0
            minute = parsed.1
        }

        guard var h = hour, h >= 0, h <= 23, minute >= 0, minute <= 59 else { return [] }

        if let pm = isPM {
            if pm && h != 12 { h += 12 }
            if !pm && h == 12 { h = 0 }
        }

        let calendar = Calendar.current
        let now = Date()
        var results: [TimeSuggestion] = []

        // Today
        var todayComp = calendar.dateComponents([.year, .month, .day], from: now)
        todayComp.hour = h
        todayComp.minute = minute
        if let todayDate = calendar.date(from: todayComp), todayDate > now {
            let label = "today at \(formatTimeLabel(h, minute))"
            results.append(TimeSuggestion(label: label, date: todayDate, formattedDate: formatDate(todayDate)))
        }

        // Tomorrow
        let tomorrowDay = calendar.date(byAdding: .day, value: 1, to: now)!
        var tomorrowComp = calendar.dateComponents([.year, .month, .day], from: tomorrowDay)
        tomorrowComp.hour = h
        tomorrowComp.minute = minute
        if let tomorrowDate = calendar.date(from: tomorrowComp) {
            let label = "tomorrow at \(formatTimeLabel(h, minute))"
            results.append(TimeSuggestion(label: label, date: tomorrowDate, formattedDate: formatDate(tomorrowDate)))
        }

        return results
    }

    // MARK: - Keyword Matching ("later", "tonight", "tomorrow", "next week")

    private func matchKeywords(_ input: String) -> [TimeSuggestion] {
        let now = Date()
        let calendar = Calendar.current

        struct Keyword {
            let match: String
            let label: String
            let date: () -> Date
        }

        let keywords: [Keyword] = [
            Keyword(match: "later today", label: "later today", date: { [self] in laterToday() }),
            Keyword(match: "later", label: "later today", date: { [self] in laterToday() }),
            Keyword(match: "tonight", label: "tonight", date: {
                var c = calendar.dateComponents([.year, .month, .day], from: now)
                c.hour = 21; c.minute = 0
                let d = calendar.date(from: c)!
                return d > now ? d : d.addingTimeInterval(86400)
            }),
            Keyword(match: "tomorrow morning", label: "tomorrow morning", date: {
                let tmrw = calendar.date(byAdding: .day, value: 1, to: now)!
                var c = calendar.dateComponents([.year, .month, .day], from: tmrw)
                c.hour = 9; c.minute = 0
                return calendar.date(from: c)!
            }),
            Keyword(match: "tomorrow", label: "tomorrow", date: {
                let tmrw = calendar.date(byAdding: .day, value: 1, to: now)!
                var c = calendar.dateComponents([.year, .month, .day], from: tmrw)
                c.hour = 9; c.minute = 0
                return calendar.date(from: c)!
            }),
            Keyword(match: "this weekend", label: "this weekend", date: { [self] in
                nextSaturday(at: 12, minute: 0)
            }),
            Keyword(match: "next week", label: "next week", date: { [self] in
                nextWeekday(.monday, at: 9)
            }),
            Keyword(match: "next month", label: "next month", date: {
                let nextMonth = calendar.date(byAdding: .month, value: 1, to: now)!
                var c = calendar.dateComponents([.year, .month], from: nextMonth)
                c.day = 1; c.hour = 9; c.minute = 0
                return calendar.date(from: c)!
            }),
            Keyword(match: "next quarter", label: "next quarter", date: {
                let month = calendar.component(.month, from: now)
                let nextQuarterMonth = ((month - 1) / 3 + 1) * 3 + 1
                var c = calendar.dateComponents([.year], from: now)
                c.month = nextQuarterMonth; c.day = 1; c.hour = 9; c.minute = 0
                if nextQuarterMonth > 12 {
                    c.year = (c.year ?? 2026) + 1
                    c.month = nextQuarterMonth - 12
                }
                return calendar.date(from: c)!
            }),
            Keyword(match: "never", label: "never", date: { .distantFuture }),
        ]

        var results: [TimeSuggestion] = []
        var seenLabels = Set<String>()

        for kw in keywords {
            if kw.match.hasPrefix(input) || input.hasPrefix(kw.match) {
                if seenLabels.insert(kw.label).inserted {
                    let date = kw.date()
                    let isNever = date == .distantFuture
                    results.append(TimeSuggestion(
                        label: kw.label,
                        date: date,
                        formattedDate: isNever ? "\u{00AF}\\_(ツ)_/\u{00AF}" : formatDate(date),
                        neverNotify: isNever
                    ))
                }
            }
        }

        return results
    }

    // MARK: - Duration ("3 hours", "30 min", "2 days")

    private func parseDuration(_ input: String) -> [TimeSuggestion] {
        let parts = input.split(separator: " ")
        guard parts.count == 2 else { return [] }

        guard let n = extractNumber(String(parts[0])), n > 0 else { return [] }

        let unit = String(parts[1])
        let now = Date()

        if unit.hasPrefix("min") {
            let date = now.addingTimeInterval(Double(n) * 60)
            return [TimeSuggestion(label: "in \(n) minute\(n == 1 ? "" : "s")", date: date, formattedDate: formatDate(date))]
        } else if unit.hasPrefix("hour") || unit == "hr" || unit == "hrs" {
            let date = now.addingTimeInterval(Double(n) * 3600)
            return [TimeSuggestion(label: "in \(n) hour\(n == 1 ? "" : "s")", date: date, formattedDate: formatDate(date))]
        } else if unit.hasPrefix("day") {
            let date = Calendar.current.date(byAdding: .day, value: n, to: now)!
            return [TimeSuggestion(label: "in \(n) day\(n == 1 ? "" : "s")", date: date, formattedDate: formatDate(date))]
        } else if unit.hasPrefix("week") {
            let date = Calendar.current.date(byAdding: .weekOfYear, value: n, to: now)!
            return [TimeSuggestion(label: "in \(n) week\(n == 1 ? "" : "s")", date: date, formattedDate: formatDate(date))]
        }

        return []
    }

    // MARK: - Day Name ("monday", "fri")

    private func parseDayName(_ input: String) -> [TimeSuggestion] {
        let dayMap: [(prefixes: [String], weekday: Int, name: String)] = [
            (["sunday", "sun"], 1, "Sunday"),
            (["monday", "mon"], 2, "Monday"),
            (["tuesday", "tue", "tues"], 3, "Tuesday"),
            (["wednesday", "wed"], 4, "Wednesday"),
            (["thursday", "thu", "thur", "thurs"], 5, "Thursday"),
            (["friday", "fri"], 6, "Friday"),
            (["saturday", "sat"], 7, "Saturday"),
        ]

        for entry in dayMap {
            for prefix in entry.prefixes {
                if prefix.hasPrefix(input) || input.hasPrefix(prefix) {
                    let date = nextWeekday(entry.weekday, at: 9)
                    return [TimeSuggestion(label: entry.name, date: date, formattedDate: formatDate(date))]
                }
            }
        }
        return []
    }

    // MARK: - NSDataDetector Fallback

    private func parseWithDataDetector(_ input: String) -> [TimeSuggestion] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else {
            return []
        }

        let range = NSRange(input.startIndex..., in: input)
        let matches = detector.matches(in: input, range: range)

        return matches.compactMap { match -> TimeSuggestion? in
            guard let date = match.date, date > Date() else { return nil }
            return TimeSuggestion(label: input, date: date, formattedDate: formatDate(date))
        }
    }

    // MARK: - Date Formatting

    public func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        let timeStr = timeFormatter.string(from: date).uppercased()

        if calendar.isDateInToday(date) {
            return timeStr
        }

        let dayFormatter = DateFormatter()
        let daysApart = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day ?? 0

        if daysApart <= 6 {
            dayFormatter.dateFormat = "EEE"
            return "\(dayFormatter.string(from: date).uppercased()), \(timeStr)"
        } else {
            dayFormatter.dateFormat = "EEE, MMM dd"
            return "\(dayFormatter.string(from: date).uppercased()), \(timeStr)"
        }
    }

    // MARK: - Helpers

    private let numberWords: [String: Int] = [
        "one": 1, "two": 2, "three": 3, "four": 4, "five": 5,
        "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10,
        "eleven": 11, "twelve": 12, "thirteen": 13, "fourteen": 14,
        "fifteen": 15, "sixteen": 16, "seventeen": 17, "eighteen": 18,
        "nineteen": 19, "twenty": 20, "thirty": 30, "forty": 40, "fifty": 50,
    ]

    private func extractNumber(_ str: String) -> Int? {
        if let n = Int(str) { return n }
        return numberWords[str]
    }

    private func splitHourMinute(_ str: String) -> (Int?, Int) {
        if str.contains(":") {
            let parts = str.split(separator: ":")
            return (Int(parts[0]), Int(parts.count > 1 ? parts[1] : "0") ?? 0)
        }
        return (Int(str), 0)
    }

    private func formatTimeLabel(_ hour24: Int, _ minute: Int) -> String {
        let h = hour24 % 12 == 0 ? 12 : hour24 % 12
        let period = hour24 >= 12 ? "pm" : "am"
        if minute == 0 {
            return "\(h) \(period)"
        }
        return "\(h):\(String(format: "%02d", minute)) \(period)"
    }

    private func laterToday() -> Date {
        let calendar = Calendar.current
        let now = Date()
        let threeHours = now.addingTimeInterval(3 * 3600)

        // Round up to nearest half hour
        var c = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: threeHours)
        let min = c.minute ?? 0
        if min <= 30 {
            c.minute = 30
        } else {
            c.minute = 0
            c.hour = (c.hour ?? 0) + 1
        }
        return calendar.date(from: c) ?? threeHours
    }

    private func nextSaturday(at hour: Int, minute: Int) -> Date {
        let calendar = Calendar.current
        let now = Date()
        let weekday = calendar.component(.weekday, from: now)

        let daysUntil: Int
        if weekday == 7 { // Already Saturday
            daysUntil = 7
        } else if weekday == 1 { // Sunday
            daysUntil = 6
        } else {
            daysUntil = 7 - weekday
        }

        let saturday = calendar.date(byAdding: .day, value: daysUntil, to: now)!
        var c = calendar.dateComponents([.year, .month, .day], from: saturday)
        c.hour = hour
        c.minute = minute
        return calendar.date(from: c)!
    }

    private func nextWeekday(_ target: Int, at hour: Int) -> Date {
        let calendar = Calendar.current
        let now = Date()
        let current = calendar.component(.weekday, from: now)

        var daysAhead = target - current
        if daysAhead <= 0 { daysAhead += 7 }

        let date = calendar.date(byAdding: .day, value: daysAhead, to: now)!
        var c = calendar.dateComponents([.year, .month, .day], from: date)
        c.hour = hour
        c.minute = 0
        return calendar.date(from: c)!
    }

    private enum Weekday: Int {
        case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday
    }

    private func nextWeekday(_ day: Weekday, at hour: Int) -> Date {
        nextWeekday(day.rawValue, at: hour)
    }

    private func addWeekdays(_ count: Int, from date: Date) -> Date {
        let calendar = Calendar.current
        var result = date
        var remaining = count
        while remaining > 0 {
            result = calendar.date(byAdding: .day, value: 1, to: result)!
            let wd = calendar.component(.weekday, from: result)
            if wd != 1 && wd != 7 { remaining -= 1 }
        }
        var c = calendar.dateComponents([.year, .month, .day], from: result)
        c.hour = 9
        c.minute = 0
        return calendar.date(from: c)!
    }

    private func generateSomedayDate() -> Date {
        let calendar = Calendar.current
        let now = Date()
        let randomDays = Int.random(in: 4...30)
        let futureDay = calendar.date(byAdding: .day, value: randomDays, to: now)!
        var c = calendar.dateComponents([.year, .month, .day], from: futureDay)
        c.hour = [9, 10, 11, 12, 14, 15, 16, 17, 18, 19, 20].randomElement()!
        c.minute = [0, 15, 30, 45].randomElement()!
        return calendar.date(from: c)!
    }

    // MARK: - On-Device Foundation Model Fallback

    public var isAIAvailable: Bool {
        guard case .available = SystemLanguageModel.default.availability else { return false }
        return true
    }

    public func aiSuggestion(for input: String) async -> TimeSuggestion? {
        guard isAIAvailable else { return nil }

        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy 'at' h:mm a"
        let nowString = formatter.string(from: now)

        let session = LanguageModelSession {
            """
            You are a date/time extraction assistant. Given natural language describing \
            when something should be scheduled, extract the precise date and time. \
            Right now it is \(nowString). \
            Calculate actual dates for relative terms like "next Tuesday", "in 3 days", \
            "after lunch", "end of the week", etc. \
            If no specific time is mentioned, default to hour=9 minute=0.
            """
        }

        do {
            let response = try await session.respond(
                to: input,
                generating: ParsedDateTime.self
            )

            let parsed = response.content
            var components = DateComponents()
            components.year = parsed.year
            components.month = parsed.month
            components.day = parsed.day
            components.hour = parsed.hour
            components.minute = parsed.minute

            guard let date = Calendar.current.date(from: components), date > now else {
                return nil
            }

            return TimeSuggestion(
                label: parsed.label,
                date: date,
                formattedDate: formatDate(date),
                isAIParsed: true
            )
        } catch {
            return nil
        }
    }
}
