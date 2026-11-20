import Foundation
import Testing
@testable import ColorFlowCore

struct AphorismTests {
    @Test func requiredBundleContains100SourcedEntriesWithoutRepetition() throws {
        let catalog = try AphorismCatalog.load()
        #expect(catalog.entries.count == 100)
        #expect(Set(catalog.entries.map(\.text)).count == catalog.entries.count)
        for entry in catalog.entries {
            #expect(catalog.entry(id: entry.id) == entry)
            let fresh = catalog.randomEntry(excluding: entry.id)
            #expect(fresh.id != entry.id)
            #expect(catalog.entry(id: fresh.id) == fresh)
        }
        #expect(catalog.entry(id: "retired") == nil)
    }

    @Test func selectedQuoteRoundTripsWithSettledBoard() throws {
        let level = try TestCatalog.levels()[0]
        let quote = try AphorismCatalog.load().randomEntry(excluding: nil)
        var progress = GameProgress(level: level)
        progress.state = try PuzzleEngine(level: level).applying(.take(queue: 0), to: progress.state)
        progress.aphorismID = quote.id
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ProgressStore(url: directory.appendingPathComponent("save.json"))
        try store.save(progress)
        #expect(store.load(levels: [level]) == progress)
        progress.startAttempt(level: level)
        #expect(progress.aphorismID == nil)
    }
}
