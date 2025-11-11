import Foundation

enum RegexExtractors {
    private static let ddMMyyyy: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        formatter.locale = Locale(identifier: "en_GB")
        return formatter
    }()

    private static let shortFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        formatter.locale = Locale(identifier: "en_GB")
        return formatter
    }()

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter
    }()

    private static let amountRegex = try! NSRegularExpression(pattern: "£\\s*[0-9]{1,3}(?:,[0-9]{3})*(?:\\.[0-9]{2})?", options: [.caseInsensitive])
    private static let vrmRegex = try! NSRegularExpression(pattern: "(?i)\\b([A-Z]{2}[0-9]{2} ?[A-Z]{3}|[A-Z]{3} ?[0-9]{3})\\b")

    static func parseDate(_ text: String) -> Date? {
        if let date = ddMMyyyy.date(from: text.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return date
        }
        if let date = shortFormatter.date(from: text.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return date
        }
        return isoFormatter.date(from: text.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    static func firstDate(matching keyword: String, in text: String) -> Date? {
        for line in text.components(separatedBy: .newlines) {
            if line.lowercased().contains(keyword.lowercased()) {
                let components = line.components(separatedBy: CharacterSet(charactersIn: ":-"))
                if let candidate = components.last, let date = parseDate(candidate) {
                    return date
                }
            }
        }
        return nil
    }

    static func extractAmount(in text: String) -> Decimal? {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = amountRegex.firstMatch(in: text, options: [], range: range),
              let matchRange = Range(match.range, in: text) else {
            return nil
        }
        let cleaned = text[matchRange]
            .replacingOccurrences(of: "£", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        return Decimal(string: cleaned)
    }

    static func extractVRM(in text: String) -> String? {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = vrmRegex.firstMatch(in: text, options: [], range: range),
              let matchRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return text[matchRange].uppercased().replacingOccurrences(of: " ", with: "")
    }

    static func firstMatch(pattern: String, text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range), match.numberOfRanges > 1 else { return nil }
        guard let captureRange = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[captureRange]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func extractPolicyNumber(in text: String) -> String? {
        firstMatch(pattern: "policy (?:number|no|ref)[#: ]+([A-Z0-9-]+)", text: text)
    }

    static func extractMPAN(in text: String) -> String? {
        firstMatch(pattern: "mpan[#: ]+([0-9 ]{10,})", text: text)
    }

    static func extractMPRN(in text: String) -> String? {
        firstMatch(pattern: "mprn[#: ]+([0-9 ]{6,})", text: text)
    }

    static func extractSortCode(in text: String) -> String? {
        firstMatch(pattern: "sort code[#: ]+([0-9-]{6,})", text: text)
    }

    static func extractAccountNumber(in text: String) -> String? {
        firstMatch(pattern: "account (?:number|no)[#: ]+([0-9]{6,})", text: text)
    }

    static func collectSection(named keyword: String, in text: String, maxLines: Int = 6) -> [String] {
        let lower = text.lowercased()
        guard let range = lower.range(of: keyword.lowercased()) else { return [] }
        let tail = text[range.upperBound...]
        var lines: [String] = []
        for line in tail.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { break }
            if trimmed.contains(":") && lines.count > 0 { break }
            lines.append(trimmed)
            if lines.count >= maxLines { break }
        }
        return lines
    }

    static func allDates(in text: String) -> [Date] {
        text.components(separatedBy: CharacterSet.whitespacesAndNewlines).compactMap(parseDate)
    }
}
