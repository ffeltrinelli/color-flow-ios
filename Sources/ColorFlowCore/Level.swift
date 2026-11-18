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

public enum Difficulty: String, Codable, CaseIterable, Sendable {
    case easy, medium, hard
}

public enum BoardKind: String, Codable, Sendable {
    case square, circular
}

public struct PaintTin: Codable, Equatable, Hashable, Sendable {
    public let color: PaintColor
    public var paintUnits: Int

    public init(color: PaintColor, paintUnits: Int) {
        self.color = color
        self.paintUnits = paintUnits
    }
}

public struct BoxDefinition: Codable, Equatable, Hashable, Identifiable, Sendable {
    public let id: Int
    public let row: Int
    public let column: Int
    public let width: Int
    public let height: Int
    public let color: PaintColor

    public init(id: Int, row: Int, column: Int, width: Int = 1, height: Int = 1, color: PaintColor) {
        self.id = id
        self.row = row
        self.column = column
        self.width = width
        self.height = height
        self.color = color
    }

    public var capacity: Int { width * height }
}

public struct LevelDefinition: Codable, Equatable, Sendable {
    public let boardKind: BoardKind
    public let id: Int
    public let difficulty: Difficulty
    public let bucketSlots: Int
    public let width: Int
    public let height: Int
    public let boxes: [BoxDefinition]
    public let paintQueues: [[PaintTin]]

    public init(id: Int, difficulty: Difficulty, bucketSlots: Int, width: Int, height: Int,
                boxes: [BoxDefinition], paintQueues: [[PaintTin]], boardKind: BoardKind = .square) {
        self.boardKind = boardKind
        self.id = id
        self.difficulty = difficulty
        self.bucketSlots = bucketSlots
        self.width = width
        self.height = height
        self.boxes = boxes
        self.paintQueues = paintQueues
    }

    private enum CodingKeys: String, CodingKey {
        case id, difficulty, bucketSlots, width, height, boxes, paintQueues, boardKind
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(id: try values.decode(Int.self, forKey: .id),
                  difficulty: try values.decode(Difficulty.self, forKey: .difficulty),
                  bucketSlots: try values.decode(Int.self, forKey: .bucketSlots),
                  width: try values.decode(Int.self, forKey: .width),
                  height: try values.decode(Int.self, forKey: .height),
                  boxes: try values.decode([BoxDefinition].self, forKey: .boxes),
                  paintQueues: try values.decode([[PaintTin]].self, forKey: .paintQueues),
                  boardKind: try values.decodeIfPresent(BoardKind.self, forKey: .boardKind) ?? .square)
    }
}

public enum LevelError: Error, Equatable {
    case invalidGrid, invalidBoxes, invalidSlots, invalidQueues, invalidQuantity, paintMismatch, invalidIDs
}

public enum LevelValidator {
    public static func validate(_ level: LevelDefinition) throws {
        guard level.id > 0, level.width > 0, level.height > 0,
              level.width <= Int.max / level.height else { throw LevelError.invalidGrid }
        try validateBoxes(level)
        guard (1...3).contains(level.bucketSlots) else { throw LevelError.invalidSlots }
        guard level.paintQueues.count == 4 else { throw LevelError.invalidQueues }
        guard level.paintQueues.joined().allSatisfy({ $0.paintUnits > 0 && $0.paintUnits <= level.width * level.height })
        else { throw LevelError.invalidQuantity }
        for color in PaintColor.allCases {
            let required = level.boxes.filter { $0.color == color }.reduce(0) { $0 + $1.capacity }
            let supplied = level.paintQueues.joined().filter { $0.color == color }.reduce(0) { $0 + $1.paintUnits }
            guard required == supplied else { throw LevelError.paintMismatch }
        }
    }

    private static func validateBoxes(_ level: LevelDefinition) throws {
        guard Set(level.boxes.map(\.id)).count == level.boxes.count else { throw LevelError.invalidIDs }
        var occupied = Set<Cell>()
        for box in level.boxes {
            guard box.id > 0, (1...3).contains(box.width), (1...3).contains(box.height),
                  box.row >= 0, box.column >= 0,
                  box.row <= level.height - box.height, box.column <= level.width - box.width
            else { throw LevelError.invalidBoxes }
            for row in box.row..<(box.row + box.height) {
                for column in box.column..<(box.column + box.width) {
                    guard occupied.insert(Cell(row: row, column: column)).inserted else { throw LevelError.invalidBoxes }
                }
            }
        }
        guard occupied.count == level.width * level.height else { throw LevelError.invalidGrid }
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

    public static func generationReport() throws -> GenerationReport {
        guard let url = Bundle.module.url(forResource: "generation", withExtension: "json") else {
            throw CocoaError(.fileReadNoSuchFile)
        }
        return try JSONDecoder().decode(GenerationReport.self, from: Data(contentsOf: url))
    }

    public static func generationMetrics() throws -> [GenerationMetrics] {
        try generationReport().metrics
    }

    public static func losingBranches() throws -> [Int: [Move]] {
        let url = Bundle.module.url(forResource: "losing-branch", withExtension: "json")!
        return try JSONDecoder().decode([Int: [Move]].self, from: Data(contentsOf: url))
    }

    public static func solutions() throws -> [[Move]] {
        let url = Bundle.module.url(forResource: "solutions", withExtension: "json")!
        return try JSONDecoder().decode([[Move]].self, from: Data(contentsOf: url))
    }
}
