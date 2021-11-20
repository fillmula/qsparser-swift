import XCTest
@testable import QSParser

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

    func testEncoderEncodesNullRepresentingStringIntoNullString() throws {
        var result = try QSEncoder().encode(User(string: "null"))
        XCTAssertEqual(result, "string=%60null%60")
        result = try QSEncoder().encode(User(string: "Null"))
        XCTAssertEqual(result, "string=%60Null%60")
        result = try QSEncoder().encode(User(string: "NULL"))
        XCTAssertEqual(result, "string=%60NULL%60")
    }

    func testEncoderEncodesNilRepresentingStringIntoNilString() throws {
        let result = try QSEncoder().encode(User(string: "nil"))
        XCTAssertEqual(result, "string=%60nil%60")
    }

    func testEncoderEncodesNoneRepresentingStringIntoNoneString() throws {
        let result = try QSEncoder().encode(User(string: "None"))
        XCTAssertEqual(result, "string=%60None%60")
    }
}
