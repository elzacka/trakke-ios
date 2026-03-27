import Foundation
import CryptoKit
import OSLog

// MARK: - Pack Download Manager

actor PackDownloadManager {
    private var activeDownloads: [String: Task<Void, Never>] = [:]

    // MARK: - Download

    func download(pack: KnowledgePack) -> AsyncStream<DownloadProgress> {
        // Cancel any existing download before creating the stream.
        // Both lines run in the actor-isolated function body — safe.
        activeDownloads[pack.id]?.cancel()
        activeDownloads.removeValue(forKey: pack.id)

        // Use makeStream() so the continuation is available in the actor-isolated
        // scope, allowing us to start the download task and register it in
        // activeDownloads without touching actor state from a nonisolated closure.
        let (stream, continuation) = AsyncStream<DownloadProgress>.makeStream()

        let task = Task {
            defer { self.removeActiveDownload(pack.id) }
            do {
                let request = Self.makeRequest(url: pack.downloadURL)
                let (tempURL, response) = try await APIClient.session.download(for: request)

                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode)
                else {
                    continuation.yield(DownloadProgress(
                        packId: pack.id, bytesWritten: 0, totalBytes: pack.fileSize, isComplete: false
                    ))
                    continuation.finish()
                    return
                }

                // Verify checksum
                guard Self.verifyChecksum(fileURL: tempURL, expected: pack.checksum) else {
                    Logger.knowledge.error("Checksum verification failed for pack: \(pack.id, privacy: .public)")
                    try? FileManager.default.removeItem(at: tempURL)
                    continuation.finish()
                    return
                }

                // Atomic move to final location
                let finalURL = PackStorageHelper.packFileURL(for: pack.id)
                PackStorageHelper.ensureDirectoryExists()

                // Remove existing file if any
                try? FileManager.default.removeItem(at: finalURL)
                try FileManager.default.moveItem(at: tempURL, to: finalURL)

                // Save metadata
                let info = InstalledPackInfo(
                    id: pack.id,
                    name: pack.name,
                    theme: pack.theme,
                    county: pack.county,
                    fileSize: pack.fileSize,
                    entryCount: pack.entryCount,
                    installedAt: Date()
                )
                self.saveInstalledPack(info)

                continuation.yield(DownloadProgress(
                    packId: pack.id,
                    bytesWritten: pack.fileSize,
                    totalBytes: pack.fileSize,
                    isComplete: true
                ))
                continuation.finish()
            } catch {
                Logger.knowledge.error("Download failed for pack \(pack.id, privacy: .public): \(error, privacy: .private)")
                continuation.finish()
            }
        }

        // Register the task in actor-isolated scope so cancelDownload(packId:) can reach it.
        activeDownloads[pack.id] = task

        // onTermination fires from a nonisolated context when the consumer stops iterating.
        // task.cancel() is safe to call from any context (Task conforms to Sendable).
        continuation.onTermination = { _ in
            task.cancel()
        }

        return stream
    }

    func cancelDownload(packId: String) {
        if let task = activeDownloads.removeValue(forKey: packId) {
            task.cancel()
        }
    }

    // MARK: - Installed Packs

    func installedPacks() -> [InstalledPackInfo] {
        Self.loadInstalledPacks()
    }

    func deletePack(packId: String) throws {
        let fileURL = PackStorageHelper.packFileURL(for: packId)
        try? FileManager.default.removeItem(at: fileURL)

        var packs = Self.loadInstalledPacks()
        packs.removeAll { $0.id == packId }
        Self.saveInstalledPacks(packs)
    }

    func deleteAllPacks() throws {
        let directory = PackStorageHelper.packsDirectory
        let fm = FileManager.default

        guard fm.fileExists(atPath: directory.path),
              let contents = try? fm.contentsOfDirectory(
                  at: directory, includingPropertiesForKeys: nil
              )
        else { return }

        for file in contents where file.pathExtension == "sqlite" || file.pathExtension == "json" {
            try? fm.removeItem(at: file)
        }
    }

    // MARK: - Private

    private func removeActiveDownload(_ packId: String) {
        activeDownloads.removeValue(forKey: packId)
    }

    private func saveInstalledPack(_ info: InstalledPackInfo) {
        var packs = Self.loadInstalledPacks()
        packs.removeAll { $0.id == info.id }
        packs.append(info)
        Self.saveInstalledPacks(packs)
    }

    private static func loadInstalledPacks() -> [InstalledPackInfo] {
        let url = PackStorageHelper.installedPacksURL
        guard let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([InstalledPackInfo].self, from: data)) ?? []
    }

    private static func saveInstalledPacks(_ packs: [InstalledPackInfo]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(packs) else { return }
        try? data.write(to: PackStorageHelper.installedPacksURL, options: .atomic)
    }

    private static func makeRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue(APIClient.userAgent, forHTTPHeaderField: "User-Agent")
        return request
    }

    static func verifyChecksum(fileURL: URL, expected: String) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: fileURL) else { return false }
        defer { try? handle.close() }
        var hasher = SHA256()
        while autoreleasepool(invoking: {
            let chunk = handle.readData(ofLength: 1024 * 1024) // 1 MB chunks
            guard !chunk.isEmpty else { return false }
            hasher.update(data: chunk)
            return true
        }) {}
        let hash = hasher.finalize()
        let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
        return hashString == expected.lowercased()
    }
}
