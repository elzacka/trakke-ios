import Foundation
import OSLog

/// Et pågående opptak, skrevet til disk mens det pågår.
///
/// Uten dette lå hele turen bare i minnet fram til du trykket stopp. Blir
/// appen avlivet av iOS – lite minne, en telefonsamtale, tomt batteri, et
/// fall i lomma – var turen borte uten spor. Det er nettopp på lange turer i
/// bakgrunnen det skjer, altså akkurat de turene det er verst å miste.
///
/// Journalen er en JSON Lines-fil: første linje er hodet med
/// starttidspunktet, deretter står hvert punkt på sin egen linje. Et
/// sjekkpunkt *legger til* de nye punktene i stedet for å skrive hele sporet
/// på nytt – helfilskrivingen som lå her før, skrev en stadig voksende fil
/// hvert tiende punkt, og på en lang tur summerte det seg til hundrevis av
/// megabyte flash-skriving. Dør appen midt i en skriving, er det bare siste
/// linje som kan være avrevet; den forkastes ved gjenoppretting, og punktene
/// før den står trygt. Filbeskyttelsen er
/// `.completeUntilFirstUserAuthentication` og ikke `.complete`, fordi
/// skrivingen skjer mens skjermen er låst – med streng beskyttelse ville
/// hvert eneste sjekkpunkt feilet i det øyeblikket det betydde noe.
struct ActivityRecordingJournal: Codable, Sendable {
    var startedAt: Date
    var trackPoints: [[Double]]

    private static let filename = "recording-journal.json"
    private static let newline = Data("\n".utf8)

    private static var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent(filename)
    }

    // MARK: - Skriving

    /// Legger nye punkter til journalen uten å røre dem som alt står der.
    ///
    /// Returnerer `false` når skrivingen feilet. Kalleren skal da *ikke*
    /// regne punktene som journalført, men prøve samme hale på nytt ved neste
    /// sjekkpunkt – et tapt sjekkpunkt skal aldri stoppe selve opptaket. Fila
    /// kuttes tilbake til utgangspunktet før feilen, så et nytt forsøk ikke
    /// kan skrive en halvskrevet hale dobbelt.
    static func append(points: [[Double]], startedAt: Date) -> Bool {
        let url = fileURL
        let encoder = JSONEncoder()
        if !FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.createDirectory(
                    at: url.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                let header = try encoder.encode(ActivityRecordingJournal(startedAt: startedAt, trackPoints: []))
                try (header + newline).write(to: url, options: [.atomic])
                try? FileManager.default.setAttributes(
                    [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                    ofItemAtPath: url.path
                )
            } catch {
                Logger.activity.error("Recording journal header write failed: \(error, privacy: .private)")
                return false
            }
        }
        do {
            let handle = try FileHandle(forUpdating: url)
            defer { try? handle.close() }
            let end = try handle.seekToEnd()
            var batch = Data()
            if end > 0 {
                // En journal skrevet av en eldre versjon slutter uten
                // linjeskift. Uten dette ville første nye punkt limt seg til
                // linjen foran og gjort den uleselig.
                try handle.seek(toOffset: end - 1)
                if try handle.read(upToCount: 1) != newline {
                    batch.append(newline)
                }
            }
            for point in points {
                batch.append(try encoder.encode(point))
                batch.append(newline)
            }
            do {
                try handle.write(contentsOf: batch)
            } catch {
                try? handle.truncate(atOffset: end)
                throw error
            }
            return true
        } catch {
            Logger.activity.error("Recording journal append failed: \(error, privacy: .private)")
            return false
        }
    }

    // MARK: - Lesing

    /// Et avbrutt opptak, hvis det finnes ett. Et spor på ett punkt regnes
    /// ikke som en tur og ryddes bort i stedet for å bli tilbudt.
    static func recover() -> ActivityRecordingJournal? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        guard let journal = decode(data) else {
            // Uleselig journal er ikke noe å ta vare på, men den skal heller
            // ikke bli liggende og gi det samme tilbudet ved hver oppstart.
            Logger.activity.error("Recording journal unreadable, discarding")
            clear()
            return nil
        }
        guard journal.trackPoints.count >= 2 else {
            clear()
            return nil
        }
        return journal
    }

    /// Leser begge formatene: hele journalen som ett JSON-dokument, slik
    /// eldre versjoner skrev den, eller linjeformatet som skrives nå. En
    /// journal som lå på disk da appen ble oppdatert midt i et avbrutt
    /// opptak, skal fortsatt kunne gjenopprettes – forkastes den stille, er
    /// turen tapt. Skilt ut fra `recover()` så formatene kan testes uten å
    /// gå via disk.
    static func decode(_ data: Data) -> ActivityRecordingJournal? {
        let decoder = JSONDecoder()
        if let legacy = try? decoder.decode(ActivityRecordingJournal.self, from: data) {
            return legacy
        }
        let lines = data.split(separator: UInt8(ascii: "\n"))
        guard let headerLine = lines.first,
              var journal = try? decoder.decode(ActivityRecordingJournal.self, from: headerLine) else {
            return nil
        }
        for line in lines.dropFirst() {
            // Dør appen midt i en skriving, er linjen avrevet. Den hoppes
            // over; punktene rundt den står trygt. Fragmentet kan stå *midt*
            // i fila: etter en gjenoppretting skriver neste sjekkpunkt nye
            // punkter bak det, og med stopp-på-første-feil ville alt etter
            // fragmentet gått tapt ved neste gjenoppretting.
            guard let point = try? decoder.decode([Double].self, from: line) else { continue }
            journal.trackPoints.append(point)
        }
        return journal
    }

    static func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    static var exists: Bool {
        FileManager.default.fileExists(atPath: fileURL.path)
    }
}
