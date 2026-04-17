import Testing
import Foundation
import CryptoKit
@testable import Trakke

// MARK: - PackStorageHelper Path Traversal Tests

@Test func packFileURLSanitizesSlashes() {
    let url = PackStorageHelper.packFileURL(for: "malicious/pack")
    #expect(!url.path.contains("malicious/pack"))
    // Allowlist strips slashes entirely
    #expect(url.lastPathComponent == "maliciouspack.sqlite")
}

@Test func packFileURLSanitizesDotDot() {
    let url = PackStorageHelper.packFileURL(for: "../../etc/passwd")
    #expect(!url.path.contains(".."))
    // Allowlist strips dots and slashes, keeping only alphanumerics/hyphens/underscores
    #expect(url.lastPathComponent == "etcpasswd.sqlite")
}

@Test func packFileURLNormalInput() {
    let url = PackStorageHelper.packFileURL(for: "survival-oslo-v1")
    #expect(url.lastPathComponent == "survival-oslo-v1.sqlite")
}

@Test func metadataFileURLSanitizesSlashes() {
    let url = PackStorageHelper.metadataFileURL(for: "malicious/pack")
    #expect(!url.path.contains("malicious/pack"))
    // Allowlist strips slashes entirely
    #expect(url.lastPathComponent == "maliciouspack.meta.json")
}

@Test func metadataFileURLSanitizesDotDot() {
    let url = PackStorageHelper.metadataFileURL(for: "../secret")
    #expect(!url.path.contains(".."))
}

// MARK: - Checksum Verification Tests

@Test func verifyChecksumCorrectHash() throws {
    let tempDir = FileManager.default.temporaryDirectory
    let tempFile = tempDir.appendingPathComponent("checksum-test-\(UUID().uuidString).bin")
    defer { try? FileManager.default.removeItem(at: tempFile) }

    let content = Data("hello world".utf8)
    try content.write(to: tempFile)

    let expected = SHA256.hash(data: content)
        .compactMap { String(format: "%02x", $0) }
        .joined()

    #expect(PackDownloadManager.verifyChecksum(fileURL: tempFile, expected: expected))
}

@Test func verifyChecksumWrongHash() throws {
    let tempDir = FileManager.default.temporaryDirectory
    let tempFile = tempDir.appendingPathComponent("checksum-test-\(UUID().uuidString).bin")
    defer { try? FileManager.default.removeItem(at: tempFile) }

    let content = Data("hello world".utf8)
    try content.write(to: tempFile)

    #expect(!PackDownloadManager.verifyChecksum(fileURL: tempFile, expected: "deadbeef"))
}

@Test func verifyChecksumMissingFile() {
    let fakeURL = URL(fileURLWithPath: "/tmp/nonexistent-\(UUID().uuidString).bin")
    #expect(!PackDownloadManager.verifyChecksum(fileURL: fakeURL, expected: "abc123"))
}

@Test func verifyChecksumCaseInsensitive() throws {
    let tempDir = FileManager.default.temporaryDirectory
    let tempFile = tempDir.appendingPathComponent("checksum-test-\(UUID().uuidString).bin")
    defer { try? FileManager.default.removeItem(at: tempFile) }

    let content = Data("test data".utf8)
    try content.write(to: tempFile)

    let expected = SHA256.hash(data: content)
        .compactMap { String(format: "%02X", $0) }  // uppercase
        .joined()

    #expect(PackDownloadManager.verifyChecksum(fileURL: tempFile, expected: expected))
}

// MARK: - Bundled Articles Tests

@Test @MainActor func loadBundledArticlesReturnsNonEmpty() {
    let articles = KnowledgeViewModel.loadBundledArticles()
    #expect(!articles.isEmpty, "SurvivalArticles.json should produce at least one article")
}

@Test @MainActor func loadBundledArticlesHaveRequiredFields() {
    let articles = KnowledgeViewModel.loadBundledArticles()
    #expect(!articles.isEmpty)
    for article in articles {
        #expect(!article.title.isEmpty)
        #expect(!article.body.isEmpty)
        #expect(!article.category.isEmpty)
        #expect(article.theme == "survival")
    }
}

// MARK: - Levenshtein Norwegian Character Tests

@Test func levenshteinNorwegianCharacters() {
    // ae, oe, aa should be treated as single characters
    #expect(Levenshtein.distance("baer", "baer") == 0)
    #expect(Levenshtein.distance("sjo", "sjo") == 0)
    #expect(Levenshtein.distance("gard", "gard") == 0)
}

@Test func levenshteinNorwegianOneEdit() {
    #expect(Levenshtein.distance("bar", "baer") == 1)
    #expect(Levenshtein.distance("sjoen", "sjen") == 1)
}

@Test func levenshteinNorwegianCaseDifference() {
    // Case difference counts as edits (unicode characters)
    let dist = Levenshtein.distance("Tromso", "tromso")
    #expect(dist == 1)
}
