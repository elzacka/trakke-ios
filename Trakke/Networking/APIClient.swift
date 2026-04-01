import Foundation

enum APIError: Error, LocalizedError, Sendable {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case rateLimited
    case decodingError(String)
    case networkError(String)
    case timeout

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return String(localized: "error.invalidURL")
        case .invalidResponse:
            return String(localized: "error.invalidResponse")
        case .httpError(let code):
            return String(localized: "error.httpError \(code)")
        case .rateLimited:
            return String(localized: "error.rateLimited")
        case .decodingError(let description):
            return String(localized: "error.decodingError \(description)")
        case .networkError(let description):
            return String(localized: "error.networkError \(description)")
        case .timeout:
            return String(localized: "error.timeout")
        }
    }
}

enum APIClient {
    static let userAgent: String = {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        return "Trakke-iOS/\(version) hei@tazk.no"
    }()

    static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        config.urlCache = URLCache(
            memoryCapacity: 20 * 1024 * 1024,  // 20 MB
            diskCapacity: 100 * 1024 * 1024     // 100 MB
        )
        config.httpAdditionalHeaders = [
            "Accept-Encoding": "gzip, deflate, br",
            "Accept-Language": "nb-NO,nb;q=0.9,no;q=0.8,en;q=0.5",
        ]
        return URLSession(configuration: config)
    }()

    static func fetch<T: Decodable>(
        _ type: T.Type,
        url: URL,
        timeout: TimeInterval? = nil
    ) async throws -> T {
        let data = try await fetchData(url: url, timeout: timeout)
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }
    }

    /// Fetch raw data with User-Agent, timeout, HTTP status validation, and single retry.
    /// Retries once after 1s for timeouts, connection loss, and 5xx server errors.
    /// Set `optional` to true for non-essential requests (species images, user guide) that
    /// should be skipped in Low Data Mode.
    static func fetchData(
        url: URL,
        timeout: TimeInterval? = nil,
        additionalHeaders: [String: String] = [:],
        optional: Bool = false
    ) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        if let timeout {
            request.timeoutInterval = timeout
        }
        if optional {
            request.allowsConstrainedNetworkAccess = false
        }
        for (key, value) in additionalHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        var lastError: Error?
        for attempt in 0...1 {
            if attempt > 0 {
                try await Task.sleep(for: .seconds(1))
            }

            let data: Data
            let response: URLResponse
            do {
                (data, response) = try await session.data(for: request)
            } catch let error as URLError where error.code == .timedOut {
                lastError = APIError.timeout
                continue
            } catch let error as URLError where error.code == .networkConnectionLost {
                lastError = APIError.networkError(error.localizedDescription)
                continue
            } catch {
                throw APIError.networkError(error.localizedDescription)
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200...299:
                return data
            case 429:
                // Respect Retry-After header if present, capped at 30s
                if attempt < 1 {
                    let retryAfter = min(
                        Double(httpResponse.value(forHTTPHeaderField: "Retry-After") ?? "") ?? 2,
                        30
                    )
                    try await Task.sleep(for: .seconds(retryAfter))
                    lastError = APIError.rateLimited
                    continue
                }
                throw APIError.rateLimited
            case 500...599:
                lastError = APIError.httpError(statusCode: httpResponse.statusCode)
                continue
            default:
                throw APIError.httpError(statusCode: httpResponse.statusCode)
            }
        }

        throw lastError ?? APIError.networkError(URLError(.unknown).localizedDescription)
    }

    static func buildURL(
        base: String,
        path: String,
        queryItems: [URLQueryItem]
    ) -> URL? {
        var components = URLComponents(string: base + path)
        components?.queryItems = queryItems
        return components?.url
    }
}
