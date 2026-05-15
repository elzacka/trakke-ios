import Foundation

enum HTTPDateParser {
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(abbreviation: "GMT")
        return formatter
    }()

    static func parseExpires(_ response: HTTPURLResponse, fallbackTTL: TimeInterval) -> Date {
        if let value = response.value(forHTTPHeaderField: "Expires"),
           let date = formatter.date(from: value) {
            return date
        }
        return Date().addingTimeInterval(fallbackTTL)
    }

    static func parseExpires(_ response: HTTPURLResponse) -> Date? {
        guard let value = response.value(forHTTPHeaderField: "Expires") else { return nil }
        return formatter.date(from: value)
    }
}
