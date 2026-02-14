import Foundation
import CoreLocation

// MARK: - Search Result

struct SearchResult: Identifiable, Sendable {
    let id: String
    let name: String
    let type: SearchResultType
    let coordinate: CLLocationCoordinate2D
    let displayName: String
    let subtext: String?
    var score: Int = 0
}

enum SearchResultType: String, Sendable {
    case address
    case place
    case coordinates
}

// MARK: - API Response Types

struct StednavnResponse: Decodable {
    let navn: [StednavnResult]

    struct StednavnResult: Decodable {
        let skrivemåte: String?
        let navneobjekttype: String?
        let kommuner: [Kommune]?
        let fylker: [Fylke]?
        let representasjonspunkt: Punkt?

        struct Kommune: Decodable {
            let kommunenavn: String?
        }

        struct Fylke: Decodable {
            let fylkesnavn: String?
        }

        struct Punkt: Decodable {
            let øst: Double? // longitude
            let nord: Double? // latitude
        }
    }
}

struct AdresseResponse: Decodable {
    let adresser: [AdresseResult]

    struct AdresseResult: Decodable {
        let adressetekst: String?
        let poststed: String?
        let postnummer: String?
        let kommunenavn: String?
        let representasjonspunkt: Punkt?

        struct Punkt: Decodable {
            let lat: Double?
            let lon: Double?
        }
    }
}

// MARK: - Scoring Constants

private enum AddressScore {
    static let exactMatch = 1000
    static let streetPrefix = 100
    static let streetContains = 50
    static let houseNumberMatch = 200
    static let letterMatch = 100
    static let noLetterBonus = 50
    static let wrongLetterPenalty = -150
    static let poorMatchThreshold = -400
    static let housePrefixMatch = 10
    static let wrongHousePenalty = -500
}

private enum PlaceScore {
    static let exact = 1000
    static let prefix = 800
    static let prefixLengthBonusMax = 100
    static let wordMatch = 600
    static let substring = 300
    static let fuzzyBase = 400
    static let fuzzyPenaltyPerChar = 100
    static let fuzzyMaxDistance = 3
    static let outdoorTypeBonus = 50
    static let shortNameBonus = 30
    static let longNamePenalty = -20
    static let threshold = 100
    static let shortNameThreshold = 15
    static let longNameThreshold = 30
}

private let outdoorTypes = Set(["fjell", "vann", "dal", "bre", "fjord", "øy"])

// MARK: - Search Service

actor SearchService {
    private static let stednavnBase = "https://ws.geonorge.no"
    private static let stednavnPath = "/stedsnavn/v1/navn"
    private static let adresseBase = "https://ws.geonorge.no"
    private static let adressePath = "/adresser/v1/sok"
    private static let placeSearchLimit = 30
    private static let addressSearchMultiplier = 3
    private static let searchTimeout: TimeInterval = 10

    func search(query: String) async -> [SearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [] }

        async let places = searchPlaces(query: trimmed)
        async let addresses = searchAddresses(query: trimmed)

        let placeResults = await places
        let addressResults = await addresses

        var combined = placeResults.prefix(6) + addressResults.prefix(3)
        combined.sort { $0.score > $1.score }

        return Array(combined.prefix(10))
    }

    // MARK: - Place Search

    private func searchPlaces(query: String) async -> [SearchResult] {
        guard let url = APIClient.buildURL(
            base: Self.stednavnBase,
            path: Self.stednavnPath,
            queryItems: [
                URLQueryItem(name: "sok", value: query),
                URLQueryItem(name: "treffPerSide", value: String(Self.placeSearchLimit)),
                URLQueryItem(name: "side", value: "1"),
                URLQueryItem(name: "utkoordsys", value: "4326"),
                URLQueryItem(name: "fuzzy", value: "true"),
            ]
        ) else { return [] }

        guard let response = try? await APIClient.fetch(
            StednavnResponse.self,
            url: url,
            timeout: Self.searchTimeout
        ) else { return [] }

        let queryLower = query.lowercased()

        return response.navn.compactMap { result -> SearchResult? in
            guard let name = result.skrivemåte,
                  let punkt = result.representasjonspunkt,
                  let lon = punkt.øst,
                  let lat = punkt.nord else { return nil }

            let score = scorePlaceResult(name: name, query: queryLower, type: result.navneobjekttype)
            guard score >= PlaceScore.threshold else { return nil }

            let kommune = result.kommuner?.first?.kommunenavn
            let fylke = result.fylker?.first?.fylkesnavn
            let subtext = [result.navneobjekttype, kommune, fylke]
                .compactMap { $0 }
                .joined(separator: ", ")

            return SearchResult(
                id: "place-\(name)-\(lat)-\(lon)",
                name: name,
                type: .place,
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                displayName: name,
                subtext: subtext.isEmpty ? nil : subtext,
                score: score
            )
        }
        .sorted { $0.score > $1.score }
    }

    private func scorePlaceResult(name: String, query: String, type: String?) -> Int {
        let nameLower = name.lowercased()
        var score = 0

        // Exact match
        if nameLower == query {
            return PlaceScore.exact
        }

        // Prefix match
        if nameLower.hasPrefix(query) {
            score = PlaceScore.prefix
            let lengthDiff = nameLower.count - query.count
            let bonus = max(0, PlaceScore.prefixLengthBonusMax - lengthDiff * 10)
            score += bonus
        }
        // Word boundary prefix match
        else if nameLower.split(separator: " ").contains(where: { $0.lowercased().hasPrefix(query) }) {
            score = PlaceScore.wordMatch
        }
        // Substring match
        else if nameLower.contains(query) {
            score = PlaceScore.substring
        }
        // Fuzzy match via Levenshtein
        else {
            let distance = Levenshtein.distance(nameLower, query)
            if distance <= PlaceScore.fuzzyMaxDistance {
                score = PlaceScore.fuzzyBase - distance * PlaceScore.fuzzyPenaltyPerChar
            }
        }

        guard score > 0 else { return 0 }

        // Outdoor type bonus
        if let type = type?.lowercased(), outdoorTypes.contains(type) {
            score += PlaceScore.outdoorTypeBonus
        }

        // Name length adjustments
        if name.count <= PlaceScore.shortNameThreshold {
            score += PlaceScore.shortNameBonus
        } else if name.count > PlaceScore.longNameThreshold {
            score += PlaceScore.longNamePenalty
        }

        return score
    }

    // MARK: - Address Search

    private func searchAddresses(query: String) async -> [SearchResult] {
        guard query.count >= 3 else { return [] }

        let limit = 5 * Self.addressSearchMultiplier

        guard let url = APIClient.buildURL(
            base: Self.adresseBase,
            path: Self.adressePath,
            queryItems: [
                URLQueryItem(name: "sok", value: query),
                URLQueryItem(name: "treffPerSide", value: String(limit)),
                URLQueryItem(name: "side", value: "0"),
                URLQueryItem(name: "asciiKompatibel", value: "true"),
            ]
        ) else { return [] }

        guard let response = try? await APIClient.fetch(
            AdresseResponse.self,
            url: url,
            timeout: Self.searchTimeout
        ) else { return [] }

        let queryLower = query.lowercased()
        let (houseNumber, houseLetter, streetName) = parseAddressQuery(queryLower)

        return response.adresser.compactMap { result -> SearchResult? in
            guard let adressetekst = result.adressetekst,
                  let punkt = result.representasjonspunkt,
                  let lat = punkt.lat,
                  let lon = punkt.lon else { return nil }

            let score = scoreAddressResult(
                address: adressetekst,
                query: queryLower,
                streetQuery: streetName,
                houseNumber: houseNumber,
                houseLetter: houseLetter
            )
            guard score > AddressScore.poorMatchThreshold else { return nil }

            let subtext = [result.postnummer, result.poststed, result.kommunenavn]
                .compactMap { $0 }
                .joined(separator: " ")

            return SearchResult(
                id: "addr-\(adressetekst)-\(lat)-\(lon)",
                name: adressetekst,
                type: .address,
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                displayName: adressetekst,
                subtext: subtext.isEmpty ? nil : subtext,
                score: score
            )
        }
        .sorted { $0.score > $1.score }
    }

    private func parseAddressQuery(_ query: String) -> (houseNumber: String?, houseLetter: String?, streetName: String) {
        let pattern = #"\b(\d+)([a-z]?)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: query, range: NSRange(query.startIndex..., in: query)),
              let numberRange = Range(match.range(at: 1), in: query) else {
            return (nil, nil, query.trimmingCharacters(in: .whitespaces))
        }

        let number = String(query[numberRange])
        var letter: String?
        if let letterRange = Range(match.range(at: 2), in: query), !query[letterRange].isEmpty {
            letter = String(query[letterRange])
        }

        let streetEnd = query.index(numberRange.lowerBound, offsetBy: 0)
        let street = String(query[query.startIndex..<streetEnd]).trimmingCharacters(in: .whitespaces)

        return (number, letter, street)
    }

    private func scoreAddressResult(
        address: String,
        query: String,
        streetQuery: String,
        houseNumber: String?,
        houseLetter: String?
    ) -> Int {
        let addressLower = address.lowercased()
        var score = 0

        // Exact match
        if addressLower == query {
            return AddressScore.exactMatch
        }

        // Street name matching
        if addressLower.hasPrefix(streetQuery) {
            score += AddressScore.streetPrefix
        } else if addressLower.contains(streetQuery) {
            score += AddressScore.streetContains
        }

        // House number matching
        if let houseNumber {
            let addressPattern = #"\b(\d+)([a-z]?)(?:\s|$)"#
            if let regex = try? NSRegularExpression(pattern: addressPattern),
               let match = regex.firstMatch(in: addressLower, range: NSRange(addressLower.startIndex..., in: addressLower)),
               let addrNumRange = Range(match.range(at: 1), in: addressLower) {
                let addrNumber = String(addressLower[addrNumRange])

                if addrNumber == houseNumber {
                    score += AddressScore.houseNumberMatch

                    // Letter matching
                    if let houseLetter {
                        if let addrLetterRange = Range(match.range(at: 2), in: addressLower),
                           !addressLower[addrLetterRange].isEmpty {
                            let addrLetter = String(addressLower[addrLetterRange])
                            if addrLetter == houseLetter {
                                score += AddressScore.letterMatch
                            } else {
                                score += AddressScore.wrongLetterPenalty
                            }
                        }
                    } else {
                        score += AddressScore.noLetterBonus
                    }
                } else if addrNumber.hasPrefix(houseNumber) {
                    score += AddressScore.housePrefixMatch
                } else {
                    score += AddressScore.wrongHousePenalty
                }
            }
        }

        // Levenshtein as minor fuzzy factor
        let distance = Levenshtein.distance(addressLower, query)
        score -= distance

        return score
    }
}
