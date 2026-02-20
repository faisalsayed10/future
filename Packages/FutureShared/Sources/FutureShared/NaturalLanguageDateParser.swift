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

        results += parseComposite(trimmed)
        results += parseNumber(trimmed)
        results += parseTimeExpression(trimmed)
        results += matchKeywords(trimmed)
        results += parseDuration(trimmed)
        results += parseDayName(trimmed)

        // DataDetector only as fallback — avoids partial matches like "five pm" inside "nine twenty five pm"
        if results.isEmpty {
            results += parseWithDataDetector(input)
        }

        var seen = Set<String>()
        results = results.filter { seen.insert($0.label).inserted }

        return Array(results.prefix(6))
    }

    public func defaultSuggestions() -> [TimeSuggestion] {
        let now = Date()
        let calendar = Calendar.current

        let inOneHour = now.addingTimeInterval(3600)
        let inThreeHours = now.addingTimeInterval(3 * 3600)

        var tonightComp = calendar.dateComponents([.year, .month, .day], from: now)
        tonightComp.hour = 21
        tonightComp.minute = 0
        let tonightRaw = calendar.date(from: tonightComp)!
        let tonight = tonightRaw > now ? tonightRaw : tonightRaw.addingTimeInterval(86400)

        let tomorrowDay = calendar.date(byAdding: .day, value: 1, to: now)!
        var tomorrowComp = calendar.dateComponents([.year, .month, .day], from: tomorrowDay)
        tomorrowComp.hour = 9
        tomorrowComp.minute = 0
        let tomorrowDate = calendar.date(from: tomorrowComp)!

        let weekendDate = nextSaturday(at: 12, minute: 0)
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

    // MARK: - Bare Number ("4", "eight", "935")

    private func parseNumber(_ input: String) -> [TimeSuggestion] {
        if input.contains(" ") { return [] }
        // Skip if it ends with anything that looks like am/pm (parseTimeExpression handles that)
        if detectAmPm(String(input.suffix(2))) != nil || detectAmPm(String(input.suffix(1))) != nil {
            return []
        }

        guard let n = extractNumber(input), n > 0, n <= 999 else { return [] }

        let now = Date()
        var results: [TimeSuggestion] = []

        // 3-4 digit numeric input: interpret as HMM or HHMM time (e.g. "935" → 9:35)
        if Int(input) != nil, input.count >= 3, input.count <= 4 {
            let h = n / 100
            let m = n % 100
            if h >= 1, h <= 12, m >= 0, m <= 59 {
                results += ambiguousTimeResults(hour12: h, minute: m)
            }
        }

        let inMinutes = now.addingTimeInterval(Double(n) * 60)
        results.append(TimeSuggestion(label: "in \(n) minute\(n == 1 ? "" : "s")", date: inMinutes, formattedDate: formatDate(inMinutes)))

        if n <= 48 {
            let inHours = now.addingTimeInterval(Double(n) * 3600)
            results.append(TimeSuggestion(label: "in \(n) hour\(n == 1 ? "" : "s")", date: inHours, formattedDate: formatDate(inHours)))
        }
        if n <= 30 {
            let inWeekdays = addWeekdays(n, from: now)
            results.append(TimeSuggestion(label: "in \(n) weekday\(n == 1 ? "" : "s")", date: inWeekdays, formattedDate: formatDate(inWeekdays)))
        }

        return results
    }

    // MARK: - Ambiguous Time (both AM and PM, nearest first)

    private func ambiguousTimeResults(hour12: Int, minute: Int) -> [TimeSuggestion] {
        let calendar = Calendar.current
        let now = Date()
        var options: [TimeSuggestion] = []

        let amHour = hour12 == 12 ? 0 : hour12
        let pmHour = hour12 == 12 ? 12 : hour12 + 12

        for h in [amHour, pmHour] {
            var todayComp = calendar.dateComponents([.year, .month, .day], from: now)
            todayComp.hour = h
            todayComp.minute = minute
            if let todayDate = calendar.date(from: todayComp), todayDate > now {
                let label = "today at \(formatTimeLabel(h, minute))"
                options.append(TimeSuggestion(label: label, date: todayDate, formattedDate: formatDate(todayDate)))
            }

            let tomorrowDay = calendar.date(byAdding: .day, value: 1, to: now)!
            var tomorrowComp = calendar.dateComponents([.year, .month, .day], from: tomorrowDay)
            tomorrowComp.hour = h
            tomorrowComp.minute = minute
            if let tomorrowDate = calendar.date(from: tomorrowComp) {
                let label = "tomorrow at \(formatTimeLabel(h, minute))"
                options.append(TimeSuggestion(label: label, date: tomorrowDate, formattedDate: formatDate(tomorrowDate)))
            }
        }

        options.sort { $0.date < $1.date }
        return Array(options.prefix(2))
    }

    // MARK: - Time Expression ("9pm", "9p", "9om", "five am", "nine twenty five pm", "3:30 pm")

    private func parseTimeExpression(_ input: String) -> [TimeSuggestion] {
        var words = input.split(separator: " ").map { String($0).lowercased() }

        // Expand hyphenated words ("twenty-five" → "twenty", "five")
        words = words.flatMap { $0.contains("-") ? $0.split(separator: "-").map(String.init) : [$0] }

        // Strip leading "at"
        if words.first == "at" { words.removeFirst() }

        // Remove "o'clock" / "oclock" / "clock"
        words = words.filter { !["o'clock", "oclock", "clock"].contains($0) }

        guard !words.isEmpty else { return [] }

        var isPM: Bool?

        // Step 1: Check if last word is an am/pm indicator (exact, progressive, or fuzzy)
        if let last = words.last {
            if let result = detectAmPm(last) {
                isPM = result
                words.removeLast()
            }
            // Step 2: Time-of-day prefix (progressive, min 2 chars to avoid "a" matching "afternoon")
            else {
                let l = last.lowercased()
                if l.count >= 2 {
                    if "morning".hasPrefix(l) { isPM = false; words.removeLast() }
                    else if "afternoon".hasPrefix(l) { isPM = true; words.removeLast() }
                    else if "evening".hasPrefix(l) { isPM = true; words.removeLast() }
                    else if "night".hasPrefix(l) { isPM = true; words.removeLast() }
                }
            }
        }

        // Step 3: Check for attached suffix on last word (e.g., "9pm", "9om", "9p")
        if isPM == nil, let last = words.last, last.count >= 2 {
            // Try 2-char suffix
            if last.count >= 3 {
                let suffix = String(last.suffix(2))
                if let result = detectAmPm(suffix) {
                    isPM = result
                    words[words.count - 1] = String(last.dropLast(2))
                }
            }
            // Try 1-char suffix
            if isPM == nil {
                let suffix = String(last.suffix(1))
                if let result = detectAmPm(suffix) {
                    isPM = result
                    words[words.count - 1] = String(last.dropLast(1))
                }
            }
        }

        // Remove filler words
        words = words.filter { !["in", "the", "o"].contains($0) }

        guard !words.isEmpty else { return [] }

        var hour: Int?
        var minute: Int = 0

        if let colonWord = words.first(where: { $0.contains(":") }) {
            let parsed = splitHourMinute(colonWord)
            hour = parsed.0
            minute = parsed.1
        } else if words.count == 1 {
            hour = extractNumber(words[0])
        } else {
            // First word is hour, remaining words form the minute
            hour = extractNumber(words[0])
            let minuteWords = Array(words.dropFirst())
            minute = parseCompoundNumber(minuteWords) ?? 0
        }

        // Must have am/pm indicator or colon format to be a valid time expression
        guard var h = hour, h >= 0, h <= 23, minute >= 0, minute <= 59 else { return [] }
        guard isPM != nil || input.contains(":") else { return [] }

        if let pm = isPM {
            if h > 12 { return [] }
            if pm && h != 12 { h += 12 }
            if !pm && h == 12 { h = 0 }
        }

        let calendar = Calendar.current
        let now = Date()
        var results: [TimeSuggestion] = []

        var todayComp = calendar.dateComponents([.year, .month, .day], from: now)
        todayComp.hour = h
        todayComp.minute = minute
        if let todayDate = calendar.date(from: todayComp), todayDate > now {
            let label = "today at \(formatTimeLabel(h, minute))"
            results.append(TimeSuggestion(label: label, date: todayDate, formattedDate: formatDate(todayDate)))
        }

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

    // MARK: - Composite: Time + Date Modifier ("5pm tomorrow", "next monday 3pm")

    private func parseComposite(_ input: String) -> [TimeSuggestion] {
        let words = input.split(separator: " ").map { String($0).lowercased() }
        guard words.count >= 2 else { return [] }

        for splitAt in 1..<words.count {
            let part1 = words[0..<splitAt].joined(separator: " ")
            let part2 = words[splitAt...].joined(separator: " ")

            if let time = extractTimeComponents(part1), let baseDate = extractBaseDate(part2) {
                return makeCompositeResults(hour: time.hour, minute: time.minute, baseDate: baseDate)
            }

            if let time = extractTimeComponents(part2), let baseDate = extractBaseDate(part1) {
                return makeCompositeResults(hour: time.hour, minute: time.minute, baseDate: baseDate)
            }
        }

        return []
    }

    private func extractTimeComponents(_ input: String) -> (hour: Int, minute: Int)? {
        var words = input.split(separator: " ").map { String($0).lowercased() }
        words = words.flatMap { $0.contains("-") ? $0.split(separator: "-").map(String.init) : [$0] }
        if words.first == "at" { words.removeFirst() }
        words = words.filter { !["o'clock", "oclock", "clock"].contains($0) }
        guard !words.isEmpty else { return nil }

        var isPM: Bool?

        if let last = words.last {
            if let result = detectAmPm(last) {
                isPM = result
                words.removeLast()
            } else {
                let l = last.lowercased()
                if l.count >= 2 {
                    if "morning".hasPrefix(l) { isPM = false; words.removeLast() }
                    else if "afternoon".hasPrefix(l) { isPM = true; words.removeLast() }
                    else if "evening".hasPrefix(l) { isPM = true; words.removeLast() }
                    else if "night".hasPrefix(l) { isPM = true; words.removeLast() }
                }
            }
        }

        if isPM == nil, let last = words.last, last.count >= 2 {
            if last.count >= 3 {
                let suffix = String(last.suffix(2))
                if let result = detectAmPm(suffix) {
                    isPM = result
                    words[words.count - 1] = String(last.dropLast(2))
                }
            }
            if isPM == nil {
                let suffix = String(last.suffix(1))
                if let result = detectAmPm(suffix) {
                    isPM = result
                    words[words.count - 1] = String(last.dropLast(1))
                }
            }
        }

        words = words.filter { !["in", "the", "o"].contains($0) }
        guard !words.isEmpty else { return nil }

        var hour: Int?
        var minute: Int = 0

        if let colonWord = words.first(where: { $0.contains(":") }) {
            let parsed = splitHourMinute(colonWord)
            hour = parsed.0
            minute = parsed.1
        } else if words.count == 1 {
            hour = extractNumber(words[0])
        } else {
            hour = extractNumber(words[0])
            let minuteWords = Array(words.dropFirst())
            minute = parseCompoundNumber(minuteWords) ?? 0
        }

        guard var h = hour, h >= 0, h <= 23, minute >= 0, minute <= 59 else { return nil }
        guard isPM != nil || input.contains(":") else { return nil }

        if let pm = isPM {
            if h > 12 { return nil }
            if pm && h != 12 { h += 12 }
            if !pm && h == 12 { h = 0 }
        }

        return (h, minute)
    }

    private func extractBaseDate(_ input: String) -> Date? {
        let trimmed = input.trimmingCharacters(in: .whitespaces).lowercased()
        let calendar = Calendar.current
        let now = Date()

        let tomorrowVariants = ["tomorrow", "tmr", "tmrw", "tmw", "tom"]
        for variant in tomorrowVariants {
            if variant.hasPrefix(trimmed) || trimmed.hasPrefix(variant) || fuzzyMatch(trimmed, variant) {
                let tmrw = calendar.date(byAdding: .day, value: 1, to: now)!
                return calendar.startOfDay(for: tmrw)
            }
        }

        if "today".hasPrefix(trimmed) || trimmed.hasPrefix("today") || fuzzyMatch(trimmed, "today") {
            return calendar.startOfDay(for: now)
        }

        if "tonight".hasPrefix(trimmed) || trimmed.hasPrefix("tonight") || fuzzyMatch(trimmed, "tonight") {
            return calendar.startOfDay(for: now)
        }

        let dayMap: [(prefixes: [String], weekday: Int)] = [
            (["sunday", "sun"], 1), (["monday", "mon"], 2), (["tuesday", "tue", "tues"], 3),
            (["wednesday", "wed"], 4), (["thursday", "thu", "thur", "thurs"], 5),
            (["friday", "fri"], 6), (["saturday", "sat"], 7),
        ]

        var words = trimmed.split(separator: " ").map(String.init)
        if words.first == "next" { words.removeFirst() }

        if words.count == 1 {
            for entry in dayMap {
                for prefix in entry.prefixes {
                    if prefix.hasPrefix(words[0]) || words[0].hasPrefix(prefix)
                        || fuzzyMatch(words[0], prefix) || fuzzyMatch(words[0], entry.prefixes[0])
                    {
                        let target = entry.weekday
                        let current = calendar.component(.weekday, from: now)
                        var daysAhead = target - current
                        if daysAhead <= 0 { daysAhead += 7 }
                        let date = calendar.date(byAdding: .day, value: daysAhead, to: now)!
                        return calendar.startOfDay(for: date)
                    }
                }
            }
        }

        return nil
    }

    private func makeCompositeResults(hour: Int, minute: Int, baseDate: Date) -> [TimeSuggestion] {
        let calendar = Calendar.current
        var comp = calendar.dateComponents([.year, .month, .day], from: baseDate)
        comp.hour = hour
        comp.minute = minute

        guard let date = calendar.date(from: comp), date > Date() else { return [] }

        let label = "\(formatDayLabel(date)) at \(formatTimeLabel(hour, minute))"
        return [TimeSuggestion(label: label, date: date, formattedDate: formatDate(date))]
    }

    private func formatDayLabel(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "today" }
        if calendar.isDateInTomorrow(date) { return "tomorrow" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }

    // MARK: - Compound Number ("twenty five" → 25)

    private func parseCompoundNumber(_ words: [String]) -> Int? {
        if words.isEmpty { return nil }
        if words.count == 1 { return extractNumber(words[0]) }

        if words.count == 2,
           let tens = extractNumber(words[0]),
           let ones = extractNumber(words[1]),
           tens >= 20, tens % 10 == 0, ones >= 1, ones <= 9 {
            return tens + ones
        }

        return nil
    }

    // MARK: - Keyword Matching (with fuzzy search)

    private func matchKeywords(_ input: String) -> [TimeSuggestion] {
        let now = Date()
        let calendar = Calendar.current

        struct Keyword {
            let match: String
            let label: String
            let date: () -> Date
        }

        let keywords: [Keyword] = [
            Keyword(match: "noon", label: "noon", date: {
                var c = calendar.dateComponents([.year, .month, .day], from: now)
                c.hour = 12; c.minute = 0
                let d = calendar.date(from: c)!
                return d > now ? d : calendar.date(byAdding: .day, value: 1, to: d)!
            }),
            Keyword(match: "midnight", label: "midnight", date: {
                let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
                var c = calendar.dateComponents([.year, .month, .day], from: tomorrow)
                c.hour = 0; c.minute = 0
                return calendar.date(from: c)!
            }),
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
            Keyword(match: "tomorrow afternoon", label: "tomorrow afternoon", date: {
                let tmrw = calendar.date(byAdding: .day, value: 1, to: now)!
                var c = calendar.dateComponents([.year, .month, .day], from: tmrw)
                c.hour = 14; c.minute = 0
                return calendar.date(from: c)!
            }),
            Keyword(match: "tomorrow evening", label: "tomorrow evening", date: {
                let tmrw = calendar.date(byAdding: .day, value: 1, to: now)!
                var c = calendar.dateComponents([.year, .month, .day], from: tmrw)
                c.hour = 19; c.minute = 0
                return calendar.date(from: c)!
            }),
            Keyword(match: "tomorrow night", label: "tomorrow night", date: {
                let tmrw = calendar.date(byAdding: .day, value: 1, to: now)!
                var c = calendar.dateComponents([.year, .month, .day], from: tmrw)
                c.hour = 21; c.minute = 0
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
            Keyword(match: "end of day", label: "end of day", date: {
                var c = calendar.dateComponents([.year, .month, .day], from: now)
                c.hour = 17; c.minute = 0
                let d = calendar.date(from: c)!
                return d > now ? d : calendar.date(byAdding: .day, value: 1, to: d)!
            }),
            Keyword(match: "eod", label: "end of day", date: {
                var c = calendar.dateComponents([.year, .month, .day], from: now)
                c.hour = 17; c.minute = 0
                let d = calendar.date(from: c)!
                return d > now ? d : calendar.date(byAdding: .day, value: 1, to: d)!
            }),
            Keyword(match: "end of week", label: "end of week", date: {
                let weekday = calendar.component(.weekday, from: now)
                let daysToFriday = (6 - weekday + 7) % 7
                let friday = calendar.date(byAdding: .day, value: daysToFriday, to: now)!
                var c = calendar.dateComponents([.year, .month, .day], from: friday)
                c.hour = 17; c.minute = 0
                let d = calendar.date(from: c)!
                return d > now ? d : calendar.date(byAdding: .weekOfYear, value: 1, to: d)!
            }),
            Keyword(match: "eow", label: "end of week", date: {
                let weekday = calendar.component(.weekday, from: now)
                let daysToFriday = (6 - weekday + 7) % 7
                let friday = calendar.date(byAdding: .day, value: daysToFriday, to: now)!
                var c = calendar.dateComponents([.year, .month, .day], from: friday)
                c.hour = 17; c.minute = 0
                let d = calendar.date(from: c)!
                return d > now ? d : calendar.date(byAdding: .weekOfYear, value: 1, to: d)!
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
            let matches = kw.match.hasPrefix(input)
                || input.hasPrefix(kw.match)
                || fuzzyMatch(input, kw.match)
            if matches {
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

    // MARK: - Duration ("3 hours", "3h", "30 min", "in 2 days", "an hour", "half hour")

    private func parseDuration(_ input: String) -> [TimeSuggestion] {
        var parts = input.split(separator: " ").map { String($0) }

        // Strip leading "in"
        if parts.first == "in" { parts.removeFirst() }

        let now = Date()

        // "a/an hour/day/week/month"
        if parts.count == 2 && (parts[0] == "a" || parts[0] == "an") {
            return durationResult(n: 1, unit: parts[1], now: now)
        }

        // "half hour", "half an hour"
        if parts.first == "half" {
            let unitParts = Array(parts.dropFirst()).filter { $0 != "an" && $0 != "a" }
            if let unit = unitParts.first, "hour".hasPrefix(unit.lowercased()) || unit.lowercased().hasPrefix("hour") {
                let date = now.addingTimeInterval(1800)
                return [TimeSuggestion(label: "in 30 minutes", date: date, formattedDate: formatDate(date))]
            }
        }

        // Compact format: "3h", "30min", "2d"
        if parts.count == 1 {
            let part = parts[0]
            if let splitIdx = part.firstIndex(where: { $0.isLetter }) {
                let numStr = String(part[part.startIndex..<splitIdx])
                let unitStr = String(part[splitIdx...])
                if let n = extractNumber(numStr), n > 0 {
                    return durationResult(n: n, unit: unitStr, now: now)
                }
            }
        }

        guard parts.count == 2 else { return [] }
        guard let n = extractNumber(parts[0]), n > 0 else { return [] }

        return durationResult(n: n, unit: parts[1], now: now)
    }

    private func durationResult(n: Int, unit: String, now: Date) -> [TimeSuggestion] {
        var results: [TimeSuggestion] = []
        let u = unit.lowercased()

        // Bidirectional prefix matching — "m" matches both minute and month, "h" matches hour, etc.
        if "minute".hasPrefix(u) || u.hasPrefix("min") {
            let date = now.addingTimeInterval(Double(n) * 60)
            results.append(TimeSuggestion(label: "in \(n) minute\(n == 1 ? "" : "s")", date: date, formattedDate: formatDate(date)))
        }
        if "hour".hasPrefix(u) || u.hasPrefix("hour") || u == "hr" || u == "hrs" {
            let date = now.addingTimeInterval(Double(n) * 3600)
            results.append(TimeSuggestion(label: "in \(n) hour\(n == 1 ? "" : "s")", date: date, formattedDate: formatDate(date)))
        }
        if "day".hasPrefix(u) || u.hasPrefix("day") {
            let date = Calendar.current.date(byAdding: .day, value: n, to: now)!
            results.append(TimeSuggestion(label: "in \(n) day\(n == 1 ? "" : "s")", date: date, formattedDate: formatDate(date)))
        }
        if "week".hasPrefix(u) || u.hasPrefix("week") {
            let date = Calendar.current.date(byAdding: .weekOfYear, value: n, to: now)!
            results.append(TimeSuggestion(label: "in \(n) week\(n == 1 ? "" : "s")", date: date, formattedDate: formatDate(date)))
        }
        if "month".hasPrefix(u) || u.hasPrefix("month") {
            let date = Calendar.current.date(byAdding: .month, value: n, to: now)!
            results.append(TimeSuggestion(label: "in \(n) month\(n == 1 ? "" : "s")", date: date, formattedDate: formatDate(date)))
        }

        return results
    }

    // MARK: - Day Name ("monday", "fri", "next tuesday") with fuzzy matching

    private func parseDayName(_ input: String) -> [TimeSuggestion] {
        var words = input.split(separator: " ").map { String($0).lowercased() }
        let hasNext = words.first == "next"
        if hasNext { words.removeFirst() }

        guard words.count == 1 else { return [] }
        let dayInput = words[0]

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
                let matches = prefix.hasPrefix(dayInput)
                    || dayInput.hasPrefix(prefix)
                    || fuzzyMatch(dayInput, prefix)
                    || fuzzyMatch(dayInput, entry.name.lowercased())
                if matches {
                    let date = nextWeekday(entry.weekday, at: 9)
                    let label = hasNext ? "next \(entry.name)" : entry.name
                    return [TimeSuggestion(label: label, date: date, formattedDate: formatDate(date))]
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

    // MARK: - Fuzzy Matching Helpers

    /// Detects am/pm from a string with exact, progressive ("a", "p"), and fuzzy ("om" → pm) matching.
    /// Returns true for PM, false for AM, nil for no match.
    private func detectAmPm(_ s: String) -> Bool? {
        let lower = s.lowercased()
        if lower.isEmpty { return nil }

        // Exact / progressive match
        if ["am", "a.m.", "a.m", "a"].contains(lower) { return false }
        if ["pm", "p.m.", "p.m", "p"].contains(lower) { return true }

        // Fuzzy: 2-char strings with at most 1 character different
        if lower.count == 2 {
            let chars = Array(lower)
            let amScore = (chars[0] == "a" ? 0 : 1) + (chars[1] == "m" ? 0 : 1)
            let pmScore = (chars[0] == "p" ? 0 : 1) + (chars[1] == "m" ? 0 : 1)

            if amScore <= 1 && amScore < pmScore { return false }
            if pmScore <= 1 && pmScore < amScore { return true }

            // Tie-break: keyboard proximity for first character
            // 'a' neighbors: q, w, s, z  |  'p' neighbors: o, l, [
            if amScore <= 1 && pmScore <= 1 {
                if "aqswz".contains(chars[0]) { return false }
                if "pol;[".contains(chars[0]) { return true }
            }
        }

        return nil
    }

    /// Levenshtein edit distance between two strings.
    private func levenshtein(_ a: String, _ b: String) -> Int {
        let m = a.count, n = b.count
        if m == 0 { return n }
        if n == 0 { return m }

        let aArr = Array(a), bArr = Array(b)
        var prev = Array(0...n)
        var curr = Array(repeating: 0, count: n + 1)

        for i in 1...m {
            curr[0] = i
            for j in 1...n {
                if aArr[i - 1] == bArr[j - 1] {
                    curr[j] = prev[j - 1]
                } else {
                    curr[j] = 1 + min(prev[j], curr[j - 1], prev[j - 1])
                }
            }
            prev = curr
        }
        return prev[n]
    }

    /// Fuzzy match: true if input is within edit distance threshold of target.
    /// Threshold scales with target length (25%, minimum 1).
    private func fuzzyMatch(_ input: String, _ target: String) -> Bool {
        let lenDiff = abs(input.count - target.count)
        let maxDist = max(1, target.count / 4)
        if lenDiff > maxDist { return false }
        return levenshtein(input, target) <= maxDist
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
        if weekday == 7 { daysUntil = 7 }
        else if weekday == 1 { daysUntil = 6 }
        else { daysUntil = 7 - weekday }

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
