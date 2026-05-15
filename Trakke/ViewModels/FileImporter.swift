import Foundation

enum FileImportError: Error {
    case unsupportedFormat
}

enum FileImporter {
    /// Synchronous dispatch by file extension. Returns the parsed array or
    /// throws `.unsupportedFormat`. Callers own the inserter, error logging
    /// and message-state since those depend on entity-specific localisation.
    static func parse<Item>(
        from url: URL,
        gpx: (URL) throws -> [Item],
        geoJSON: (URL) throws -> [Item]
    ) throws -> [Item] {
        switch url.pathExtension.lowercased() {
        case "gpx":
            return try gpx(url)
        case "geojson", "json":
            return try geoJSON(url)
        default:
            throw FileImportError.unsupportedFormat
        }
    }

    /// Async variant that runs the chosen parser off the current actor.
    /// Cancelling the awaiting task propagates to the detached parsing task.
    static func parseOffActor<Item: Sendable>(
        from url: URL,
        gpx: @Sendable @escaping (URL) throws -> [Item],
        geoJSON: @Sendable @escaping (URL) throws -> [Item]
    ) async throws -> [Item] {
        let parser: @Sendable (URL) throws -> [Item]
        switch url.pathExtension.lowercased() {
        case "gpx":
            parser = gpx
        case "geojson", "json":
            parser = geoJSON
        default:
            throw FileImportError.unsupportedFormat
        }

        let task = Task.detached(priority: .userInitiated) {
            try parser(url)
        }
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }
}
