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
            return "For mange forsok"
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
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config)
    }()

    static func fetch<T: Decodable>(
        _ type: T.Type,
        url: URL,
        timeout: TimeInterval? = nil
    ) async throws -> T {
        var request = URLRequest(url: url)
        if let timeout {
            request.timeoutInterval = timeout
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
            throw APIError.networkError(URLError(.badServerResponse))
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
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
