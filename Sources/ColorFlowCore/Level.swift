import Foundation

public enum PaintColor: String, Codable, CaseIterable, Sendable {
    case red = "R", green = "G", blue = "B", yellow = "Y", purple = "P"

    public var name: String {
        switch self {
        case .red: "Red"
        case .green: "Green"
        case .blue: "Blue"
        case .yellow: "Yellow"
        case .purple: "Purple"
        }
    }
}

public enum Difficulty: String, Codable, Sendable {
    case easy, medium, hard
}

public struct PaintTin: Codable, Equatable, Hashable, Sendable {
    public let color: PaintColor
    public var paintUnits: Int

    public init(color: PaintColor, paintUnits: Int) {
        self.color = color
        self.paintUnits = paintUnits
    }
}

public struct LevelDefinition: Codable, Equatable, Sendable {
    public let id: Int
    public let difficulty: Difficulty
    public let bucketSlots: Int
    public let grid: [String]
    public let paintQueues: [[PaintTin]]

    public init(id: Int, difficulty: Difficulty, bucketSlots: Int, grid: [String], paintQueues: [[PaintTin]]) {
        self.id = id
        self.difficulty = difficulty
        self.bucketSlots = bucketSlots
        self.grid = grid
        self.paintQueues = paintQueues
    }

    public var width: Int { grid.first?.count ?? 0 }
    public var height: Int { grid.count }
    public var colors: [[PaintColor]] { grid.map { $0.compactMap { PaintColor(rawValue: String($0)) } } }
}

public enum LevelError: Error, Equatable {
    case invalidGrid, invalidSlots, invalidQueues, invalidQuantity, paintMismatch, invalidIDs
}

public enum LevelValidator {
    public static func validate(_ level: LevelDefinition) throws {
        guard level.id > 0, level.width > 0, level.height > 0,
              level.grid.allSatisfy({ row in
                  row.count == level.width && row.allSatisfy { PaintColor(rawValue: String($0)) != nil }
              }) else { throw LevelError.invalidGrid }
        guard (1...3).contains(level.bucketSlots) else { throw LevelError.invalidSlots }
        guard level.paintQueues.count == 4 else { throw LevelError.invalidQueues }
        guard level.paintQueues.joined().allSatisfy({ $0.paintUnits > 0 && $0.paintUnits <= level.width * level.height })
        else { throw LevelError.invalidQuantity }
        for color in PaintColor.allCases {
            let required = level.colors.joined().filter { $0 == color }.count
            let supplied = level.paintQueues.joined().filter { $0.color == color }.reduce(0) { $0 + $1.paintUnits }
            guard required == supplied else { throw LevelError.paintMismatch }
        }
    }
}

public enum LevelCatalog {
    public static func load() throws -> [LevelDefinition] {
        let url = Bundle.module.url(forResource: "levels", withExtension: "json")!
        let levels = try JSONDecoder().decode([LevelDefinition].self, from: Data(contentsOf: url))
        guard levels.map(\.id) == Array(1...max(1, levels.count)) else { throw LevelError.invalidIDs }
        try levels.forEach(LevelValidator.validate)
        return levels
    }

    public static func hardLosingBranch() throws -> [Move] {
        let url = Bundle.module.url(forResource: "losing-branch", withExtension: "json")!
        return try JSONDecoder().decode([Move].self, from: Data(contentsOf: url))
    }

    public static func solutions() throws -> [[Move]] {
        let url = Bundle.module.url(forResource: "solutions", withExtension: "json")!
        return try JSONDecoder().decode([[Move]].self, from: Data(contentsOf: url))
    }
}
