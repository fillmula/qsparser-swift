import XCTest
@testable import QSParser

public enum StringQuery: Codable {
    case eq(_ value: String)
    case contains(_ value: String, mode: Mode = .default)
    case prefix(_ value: String, mode: Mode = .default)
    case suffix(_ value: String, mode: Mode = .default)
    case match(_ value: String, mode: Mode = .default)
    case or(_ values: [StringQuery])
    case and(_ values: [StringQuery])

    public enum Mode: String, Codable {
        case `default` = "default"
        case caseInsensitive = "caseInsensitive"
    }

    public enum CodingKeys: String, CodingKey {
        case eq = "_eq"
        case contains = "_contains"
        case prefix = "_prefix"
        case suffix = "_suffix"
        case match = "_match"
        case mode = "_mode"
        case or = "_or"
        case and = "_and"
    }

    public init(from decoder: Decoder) throws {
        let container = try! decoder.container(keyedBy: CodingKeys.self)
        if container.contains(.eq) {
            self = .eq(try! container.decode(String.self, forKey: .eq))
        } else if container.contains(.contains) {
            self = .contains(
                try! container.decode(String.self, forKey: .contains),
                mode: (try? container.decode(Mode.self, forKey: .mode)) ?? .default
            )
        } else if container.contains(.prefix) {
            self = .prefix(
                try! container.decode(String.self, forKey: .prefix),
                mode: (try? container.decode(Mode.self, forKey: .mode)) ?? .default
            )
        } else if container.contains(.suffix) {
            self = .suffix(
                try! container.decode(String.self, forKey: .suffix),
                mode: (try? container.decode(Mode.self, forKey: .mode)) ?? .default
            )
        } else if container.contains(.match) {
            self = .match(
                try! container.decode(String.self, forKey: .match),
                mode: (try? container.decode(Mode.self, forKey: .mode)) ?? .default
            )
        } else if container.contains(.or) {
            self = .or(try! container.decode([StringQuery].self, forKey: .or))
        } else if container.contains(.and) {
            self = .and(try! container.decode([StringQuery].self, forKey: .and))
        } else {
            self = .eq("")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .eq(let value):
            try! container.encode(value, forKey: .eq)
        case .contains(let value, let mode):
            try! container.encode(value, forKey: .contains)
            if mode != .default {
                try! container.encode(mode, forKey: .mode)
            }
        case .prefix(let value, let mode):
            try! container.encode(value, forKey: .prefix)
            if mode != .default {
                try! container.encode(mode, forKey: .mode)
            }
        case .suffix(let value, let mode):
            try! container.encode(value, forKey: .suffix)
            if mode != .default {
                try! container.encode(mode, forKey: .mode)
            }
        case .match(let value, let mode):
            try! container.encode(value, forKey: .match)
            if mode != .default {
                try! container.encode(mode, forKey: .mode)
            }
        case .or(let value):
            try! container.encode(value, forKey: .or)
        case .and(let value):
            try! container.encode(value, forKey: .and)
        }
    }
}

struct Product: Encodable {
    var name: String
}

struct User: Encodable {
    var string: String? = nil
    var int: Int? = nil
    var double: Double? = nil
    var bool: Bool? = nil
    var date: Date? = nil
    var array: [UInt64] = []
    var dictionary: [String: String] = [:]
    var query: StringQuery? = nil
    var products: [Product] = []
}

final class EncoderTests: XCTestCase {

    func testEncoderEncodesIntIntoInt() throws {
        let result = try QSEncoder().encode(User(int: 500))
        XCTAssertEqual(result, "int=500")
    }

    func testEncoderEncodesFloatIntoFloat() throws {
        let result = try QSEncoder().encode(User(double: 500.557))
        XCTAssertEqual(result, "double=500.557")
    }

    func testEncoderEncodesTrueIntoTrue() throws {
        let result = try QSEncoder().encode(User(bool: true))
        XCTAssertEqual(result, "bool=true")
    }

    func testEncoderEncodesFalseIntoFalse() throws {
        let result = try QSEncoder().encode(User(bool: false))
        XCTAssertEqual(result, "bool=false")
    }

    func testEncoderEncodesStringIntoString() throws {
        let result = try QSEncoder().encode(User(string: "hiangtsai"))
        XCTAssertEqual(result, "string=hiangtsai")
    }

    func testEncoderEncodesDateIntoString() throws {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let dateString = formatter.string(from: now)
        let encoded = dateString.addingPercentEncoding(withAllowedCharacters: NSCharacterSet.alphanumerics)!
        let result = try QSEncoder().encode(User(date: now))
        XCTAssertEqual(result, "date=\(encoded)")
    }

    func testEncoderEncodesWhitespaces() throws {
        let result = try QSEncoder().encode(User(string: "tang thai ku"))
        XCTAssertEqual(result, "string=tang%20thai%20ku")
    }

    func testEncoderEncodesSpecialChars() throws {
        let result = try QSEncoder().encode(User(string: "俊"))
        XCTAssertEqual(result, "string=%E4%BF%8A")
    }

    func testEncoderConcatsMultipleItemsWithTheAmpersand() throws {
        let result = try QSEncoder().encode(User(string: "俊", int: 50))
        XCTAssertEqual(result, "string=%E4%BF%8A&int=50")
    }

    func testEncoderEncodesNestedCodableIntoMultipleEntries() throws {
        let result = try QSEncoder().encode(User(query: .or([.eq(":"), .eq("超")])))
        XCTAssertEqual(result, "query[_or][0][_eq]=%3A&query[_or][1][_eq]=%E8%B6%85")
    }

    func testEncoderEncodesListIntoMultipleEntries() throws {
        let result = try QSEncoder().encode(User(array: [77889900, 1010101010]))
        XCTAssertEqual(result, "array[0]=77889900&array[1]=1010101010")
    }

    func testEncoderEncodesNestedItemsIntoALongString() throws {
        let result = try QSEncoder().encode(User(products: [
            Product(name: "Q"),
            Product(name: "W")
        ]))
        XCTAssertEqual(result, "products[0][name]=Q&products[1][name]=W")
    }
}
