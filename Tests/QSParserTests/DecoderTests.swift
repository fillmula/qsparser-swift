import XCTest
@testable import QSParser

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

    func testDecoderDecodesDictsInLists() throws {
        let user = try QSDecoder().decode(User.self, from: "products[0][name]=Q&products[1][name]=W")
        XCTAssertEqual(user.products!.count, 2)
        XCTAssertEqual(user.products![0].name, "Q")
        XCTAssertEqual(user.products![1].name, "W")
    }

    func testDecoderDecodesEmptyStringIntoEmptyObject() throws {
        let user = try QSDecoder().decode(User.self, from: "")
        XCTAssertEqual(user.int, nil)
    }

    func testDecoderDecodesNullIntoNil() throws {
        let user = try QSDecoder().decode(User.self, from: "int=null&double=null&string=None")
        XCTAssertEqual(user.int, nil)
        XCTAssertEqual(user.double, nil)
        XCTAssertEqual(user.string, nil)
    }

    func testDecoderDecodesNullRepresentingStringIntoNullString() throws {
        var user = try QSDecoder().decode(User.self, from: "string=%60null%60")
        XCTAssertEqual(user.string, "null")
        user = try QSDecoder().decode(User.self, from: "string=%60Null%60")
        XCTAssertEqual(user.string, "Null")
        user = try QSDecoder().decode(User.self, from: "string=%60NULL%60")
        XCTAssertEqual(user.string, "NULL")
    }

    func testDecoderDecodesNilRepresentingStringIntoNilString() throws {
        let user = try QSDecoder().decode(User.self, from: "string=%60nil%60")
        XCTAssertEqual(user.string, "nil")
    }

    func testDecoderDecodesNoneRepresentingStringIntoNoneString() throws {
        let user = try QSDecoder().decode(User.self, from: "string=%60None%60")
        XCTAssertEqual(user.string, "None")
    }
}
