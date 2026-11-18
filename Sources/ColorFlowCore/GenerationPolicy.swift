protocol GenerationPolicy: Sendable {
    func minimumArea(profile: GenerationProfile) -> Int
    func initialShapes(profile: GenerationProfile, random: inout LevelRandom) -> [(Int, Int)]?
    func accepts(level: LevelDefinition, moves: [Move]) throws -> Bool
}

struct SquareGeneration: GenerationPolicy {
    func minimumArea(profile: GenerationProfile) -> Int { profile.shapes.reduce(0) { $0 + $1.0 * $1.1 } }
    func initialShapes(profile: GenerationProfile, random: inout LevelRandom) -> [(Int, Int)]? {
        random.shuffle(profile.shapes).sorted { $0.0 * $0.1 > $1.0 * $1.1 }
    }
    func accepts(level: LevelDefinition, moves: [Move]) throws -> Bool { true }
}

struct CircularGeneration: GenerationPolicy {
    func minimumArea(profile: GenerationProfile) -> Int { 2 }
    func initialShapes(profile: GenerationProfile, random: inout LevelRandom) -> [(Int, Int)]? {
        // Preserve the recorded generator's random sequence before selecting a subset.
        _ = random.shuffle(profile.shapes)
        let wide = profile.shapes.filter { $0.0 > 1 && $0.0 * $0.1 <= profile.largeBoxArea }
        guard !wide.isEmpty else { return nil }
        return [wide[random.index(wide.count)]]
    }
    func accepts(level: LevelDefinition, moves: [Move]) throws -> Bool {
        try PathFeatures(level: level, moves: moves).hasFall
    }
}

extension BoardKind {
    var generationPolicy: any GenerationPolicy {
        switch self {
        case .square: SquareGeneration()
        case .circular: CircularGeneration()
        }
    }
}
