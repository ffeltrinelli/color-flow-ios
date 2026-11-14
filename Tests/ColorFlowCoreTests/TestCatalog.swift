import ColorFlowCore
import Foundation

/// Fixed engine/search examples; publishing more levels does not expand unit-test work.
enum TestCatalog {
    private struct Fixture: Decodable, Sendable {
        let level: LevelDefinition
        let solution: [Move]
        let losingBranch: [Move]?
    }

    private static let fixtures: Result<[Fixture], Error> = Result {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle(for: FixtureBundle.self)
        #endif
        guard let url = bundle.url(forResource: "fixtures", withExtension: "json") else {
            throw CocoaError(.fileReadNoSuchFile)
        }
        return try JSONDecoder().decode([Fixture].self, from: Data(contentsOf: url))
    }

    static func levels() throws -> [LevelDefinition] { try fixtures.get().map(\.level) }
    static func solutions() throws -> [[Move]] { try fixtures.get().map(\.solution) }
    static func losingBranches() throws -> [Int: [Move]] {
        try Dictionary(uniqueKeysWithValues: fixtures.get().compactMap { fixture in
            fixture.losingBranch.map { (fixture.level.id, $0) }
        })
    }
}

private final class FixtureBundle: NSObject {}
