import Foundation

struct SoundpackConfig: Decodable {
    let id: UUID
    let metadata: SoundpackConfigMetadata
    let license: License
    let sounds: [String: KeySound]
}

struct SoundpackConfigMetadata: Decodable {
    let name: String
    let brand: String
    let author: String
    let category: String
    let supportsKeyUp: Bool
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        brand = try container.decode(String.self, forKey: .brand)
        author = try container.decode(String.self, forKey: .author)
        category = try container.decodeIfPresent(String.self, forKey: .category) ?? "keyboard"
        supportsKeyUp = try container.decodeIfPresent(Bool.self, forKey: .supportsKeyUp) ?? false
    }
    
    private enum CodingKeys: String, CodingKey {
        case name, brand, author, category, supportsKeyUp
    }
}

struct License: Decodable {
    let type: String
    let url: String
}

struct KeySound: Decodable {
    let down: [String]
    let up: [String]
    
    private enum CodingKeys: String, CodingKey { case down, up }
    
    /// File names are stored in Unicode NFC. macOS may list names in NFD (e.g. Arabic "أ" = "ا" + hamza),
    /// so every name is normalized once here and again when the directory is listed; lookups then always match.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        down = try c.decode([String].self, forKey: .down).map { $0.precomposedStringWithCanonicalMapping }
        up = try c.decode([String].self, forKey: .up).map { $0.precomposedStringWithCanonicalMapping }
    }
}
