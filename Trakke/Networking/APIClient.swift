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

    /// Egen referanse til sesjonens cache: `session.configuration` returnerer
    /// en KOPI, så GDPR-sletting må tømme via denne – ikke via konfigurasjonen.
    /// Egen katalog (ikke delt med URLCache.shared) slik at sletting virker
    /// deterministisk og kan verifiseres.
    static let urlCache = URLCache(
        memoryCapacity: 20 * 1024 * 1024,  // 20 MB
        diskCapacity: 100 * 1024 * 1024,    // 100 MB
        directory: FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("APIClientCache")
    )

    static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        config.urlCache = urlCache
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
            } catch is CancellationError {
                throw CancellationError()
            } catch let cancelled as URLError where cancelled.code == .cancelled {
                // Et avbrutt kall er ikke en feil. Uten dette ble det pakket om
                // til APIError.networkError(error.localizedDescription), altså
                // «avbrutt», og kallernes `catch is CancellationError` traff
                // aldri – så hver panorering som rakk å starte et kall
                // loggførte «POI fetch error», og ekte feil ble umulige å
                // skille fra normal bruk.
                throw CancellationError()
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

    /// Conditional GET with retry on timeout/5xx/429, User-Agent injection, and
    /// pass-through of `200`/`304`/`4xx` so the caller can branch on cache state.
    /// Use this for upstream services that require `If-Modified-Since`/`Last-Modified`
    /// negotiation (MET ToS).
    static func fetchDataConditional(
        url: URL,
        ifModifiedSince: String? = nil,
        timeout: TimeInterval? = nil,
        additionalHeaders: [String: String] = [:]
    ) async throws -> ConditionalFetchResult {
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        if let timeout {
            request.timeoutInterval = timeout
        }
        if let ifModifiedSince {
            request.setValue(ifModifiedSince, forHTTPHeaderField: "If-Modified-Since")
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
            } catch is CancellationError {
                throw CancellationError()
            } catch let cancelled as URLError where cancelled.code == .cancelled {
                // Et avbrutt kall er ikke en feil. Uten dette ble det pakket om
                // til APIError.networkError(error.localizedDescription), altså
                // «avbrutt», og kallernes `catch is CancellationError` traff
                // aldri – så hver panorering som rakk å starte et kall
                // loggførte «POI fetch error», og ekte feil ble umulige å
                // skille fra normal bruk.
                throw CancellationError()
            } catch {
                throw APIError.networkError(error.localizedDescription)
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 429:
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
                return ConditionalFetchResult(data: data, response: httpResponse)
            }
        }

        throw lastError ?? APIError.networkError(URLError(.unknown).localizedDescription)
    }

    /// GDPR-sletting: tømmer sesjonens private URLCache. API-svarene (vær,
    /// luftkvalitet, badetemperatur, Varsom, geokoding) er nøklet på URL-er
    /// som inneholder brukerens trunkerte koordinater, og ligger i DENNE
    /// cachen – `URLCache.shared` dekker den ikke.
    static func clearCache() {
        urlCache.removeAllCachedResponses()
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

struct ConditionalFetchResult: Sendable {
    let data: Data
    let response: HTTPURLResponse

    var statusCode: Int { response.statusCode }
    var notModified: Bool { response.statusCode == 304 }
    var ok: Bool { (200...299).contains(response.statusCode) }
    var lastModified: String? { response.value(forHTTPHeaderField: "Last-Modified") }

    func expires(fallbackTTL: TimeInterval) -> Date {
        HTTPDateParser.parseExpires(response, fallbackTTL: fallbackTTL)
    }
}
