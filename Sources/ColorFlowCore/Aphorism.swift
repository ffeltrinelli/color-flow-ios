import Foundation

public struct Aphorism: Decodable, Equatable, Sendable {
    public let id: String
    public let text: String
    public let author: String
    public let work: String
}

public struct AphorismCatalog: Sendable {
    public let entries: [Aphorism]

    public static func load() throws -> AphorismCatalog {
        guard let url = Bundle.module.url(forResource: "aphorisms", withExtension: "json") else {
            throw CocoaError(.fileReadNoSuchFile)
        }
        let entries = try JSONDecoder().decode([Aphorism].self, from: Data(contentsOf: url))
        guard entries.count == 100, Set(entries.map(\.id)).count == entries.count,
              entries.allSatisfy({ entry in
                  [entry.id, entry.text, entry.author, entry.work].allSatisfy {
                      !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                  }
              }) else { throw CocoaError(.fileReadCorruptFile) }
        return AphorismCatalog(entries: entries)
    }

    public func entry(id: String?) -> Aphorism? {
        guard let id else { return nil }
        return entries.first { $0.id == id }
    }

    public func randomEntry(excluding id: String?) -> Aphorism {
        let candidates = entries.filter { $0.id != id }
        return candidates[Int.random(in: candidates.indices)]
    }
}
