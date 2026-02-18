import Foundation

enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case rateLimited
    case decodingError(Error)
    case networkError(Error)
    case timeout

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Ugyldig URL"
        case .invalidResponse:
            return "Ugyldig respons"
        case .httpError(let code):
            return "HTTP-feil: \(code)"
        case .rateLimited:
            return "For mange forsøk"
        case .decodingError(let error):
            return "Dekodingsfeil: \(error.localizedDescription)"
        case .networkError(let error):
            return "Nettverksfeil: \(error.localizedDescription)"
        case .timeout:
            return "Tidsavbrudd"
        }
    }
}

enum APIClient {
    static let userAgent = "Trakke-iOS/1.0.0 hei@tazk.no"

    static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        config.httpAdditionalHeaders = [
            "Accept-Encoding": "gzip, deflate, br",
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
            throw APIError.decodingError(error)
        }
    }

    /// Fetch raw data with User-Agent, timeout, and HTTP status validation.
    /// Use this for non-JSON responses (XML, GML, etc.).
    static func fetchData(
        url: URL,
        timeout: TimeInterval? = nil,
        additionalHeaders: [String: String] = [:]
    ) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        if let timeout {
            request.timeoutInterval = timeout
        }
        for (key, value) in additionalHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .timedOut {
            throw APIError.timeout
        } catch {
            throw APIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            return data
        case 429:
            throw APIError.rateLimited
        default:
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
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
