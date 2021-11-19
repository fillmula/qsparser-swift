import XCTest
@testable import QSParser

//struct User: Codable {
//    var string: String? = nil
//    var int: Int? = nil
//    var double: Double? = nil
//    var bool: Bool? = nil
//    var date: Date? = nil
//    var array: [UInt64] = []
//    var dictionary: [String: String] = [:]
//    var query: StringQuery? = nil
//    var products: [Product] = []
//}

final class DecoderTests: XCTestCase {

    func testDecoderDecodesIntIntoInt() throws {
        let user = try QSDecoder().decode(User.self, from: "int=588")
        XCTAssertEqual(user.int, 588)
    }

    func testDecoderDecodesFloatIntoFloat() throws {
        let user = try QSDecoder().decode(User.self, from: "double=588.588")
        XCTAssertEqual(user.double, 588.588)
    }

    func testDecoderDecodesTrueIntoTrue() throws {
        let user = try QSDecoder().decode(User.self, from: "bool=true")
        XCTAssertEqual(user.bool, true)
    }

    func testDecoderDecodesFalseIntoFalse() throws {
        let user = try QSDecoder().decode(User.self, from: "bool=false")
        XCTAssertEqual(user.bool, false)
    }

    func testDecoderDecodesStringIntoString() throws {
        let user = try QSDecoder().decode(User.self, from: "string=KOF2003")
        XCTAssertEqual(user.string, "KOF2003")
    }

    func testDecoderDecodesWhitespaces() throws {
        let user = try QSDecoder().decode(User.self, from: "string=KOF%20XV")
        XCTAssertEqual(user.string, "KOF XV")
    }

    func testDecoderDecodesSpecialChars() throws {
        let user = try QSDecoder().decode(User.self, from: "string=%E4%BF%8A")
        XCTAssertEqual(user.string, "俊")
    }

    func testDecoderDecodesMultipleItemsToASingleObject() throws {
        let user = try QSDecoder().decode(User.self, from: "string=%E4%BF%8A&double=15")
        XCTAssertEqual(user.string, "俊")
        XCTAssertEqual(user.double, 15)
    }

    func testDecoderDecodesEntriesIntoMultipleNestedObjects() throws {
        let user = try QSDecoder().decode(User.self, from: "int=5&products[0][name]=Q")
        XCTAssertEqual(user.int, 5)
        XCTAssertEqual(user.products!.count, 1)
        XCTAssertEqual(user.products![0].name, "Q")
    }

    func testDecoderDecodesListIntoMultipleNestedObject() throws {
    }

    func testDecoderDecodesDictsInLists() throws {
    }

    func testDecoderDecodesALongStringIntoNestedItems() throws {
    }

    func testDecoderDecodesEmptyStringIntoEmptyObject() throws {
    }
}
