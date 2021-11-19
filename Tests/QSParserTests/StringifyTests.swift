import XCTest
@testable import QSParser


final class StringifyTests: XCTestCase {
    
    func testStringifyEncodesIntIntoInt() throws {
        XCTAssertEqual(stringify(["a" : 5]), "a=5")
    }
    
    func testStringifyEncodesFloatIntoFloat() throws {
        XCTAssertEqual(stringify(["a" : 5.5]), "a=5.5")
    }
    
    func testStringifyEncodesTrueIntoTrue() throws {
        XCTAssertEqual(stringify(["a" : true]), "a=true")
    }
    
    func testStringifyEncodesFalseIntoFalse() throws {
        XCTAssertEqual(stringify(["a" : false]), "a=false")
    }
    
    func testStringifyEncodesStringIntoString() throws {
        XCTAssertEqual(stringify(["a" : "b"]), "a=b")
    }

    func testStringifyEncodesDateIntoString() throws {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let dateString = formatter.string(from: now)
        let encoded = dateString.addingPercentEncoding(withAllowedCharacters: NSCharacterSet.alphanumerics)!
        XCTAssertEqual(stringify(["a" : now]), "a=\(encoded)")
    }

    func testStringifyEncodesWhitespaces() throws {
        XCTAssertEqual(stringify(["a" : "b c"]), "a=b%20c")
    }
    
    func testStringifyEncodesSpecialChars() throws {
        XCTAssertEqual(stringify(["a" : "俊"]), "a=%E4%BF%8A")
    }
    
    func testStringifyConcatsMultipleItemsWithTheAmpersand() throws {
        let result = ["a=b&c=d", "c=d&a=b"].contains(stringify(["a": "b", "c": "d"]))
        XCTAssertEqual(result, true)
    }
    
    func testStringifyEncodesDictIntoMultipleEntries() throws {
        let obj = ["a": ["b": "c"], "d": ["e": "f", "g": "h"]]
        let result = [
            "a[b]=c&d[e]=f&d[g]=h",
            "d[e]=f&d[g]=h&a[b]=c",
            "d[g]=h&d[e]=f&a[b]=c",
            "a[b]=c&d[g]=h&d[e]=f",
        ].contains(stringify(obj))
        XCTAssertEqual(result, true)
    }
    
    func testStringifyEncodesListIntoMultipleEntries() throws {
        let obj = ["a": [1, 2, 3], "b": ["q", "w", "e"]]
        let result = [
            "a[0]=1&a[1]=2&a[2]=3&b[0]=q&b[1]=w&b[2]=e",
            "b[0]=q&b[1]=w&b[2]=e&a[0]=1&a[1]=2&a[2]=3"
        ].contains(stringify(obj))
        XCTAssertEqual(result, true)
    }
    
    func testStringifyEncodesNestedItemsIntoALongString() throws {
        let obj = ["_includes": [["favorites": ["_includes": ["user"]]]]]
        XCTAssertEqual(stringify(obj), "_includes[0][favorites][_includes][0]=user")
    }
}
