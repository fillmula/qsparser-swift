import XCTest
@testable import qsparser


final class stringifyTests: XCTestCase {
    
    func testStringifyEncodesIntIntoInt() throws {
        XCTAssertEqual(stringify(obj: ["a" : 5]), "a=5")
    }
    
    func testStringifyEncodesFloatIntoFloat() throws {
        XCTAssertEqual(stringify(obj: ["a" : 5.5]), "a=5.5")
    }
    
    func testStringifyEncodesTrueIntoTrue() throws {
        XCTAssertEqual(stringify(obj: ["a" : true]), "a=true")
    }
    
    func testStringifyEncodesFalseIntoFalse() throws {
        XCTAssertEqual(stringify(obj: ["a" : false]), "a=false")
    }
    
    func testStringifyEncodesStringIntoString() throws {
        XCTAssertEqual(stringify(obj: ["a" : "b"]), "a=b")
    }
    
    func testStringifyEncodesWhitespaces() throws {
        XCTAssertEqual(stringify(obj: ["a" : "b c"]), "a=b%20c")
    }
    
    func testStringifyEncodesSpecialChars() throws {
        XCTAssertEqual(stringify(obj: ["a" : "俊"]), "a=%E4%BF%8A")
    }
    
    func testStringifyConcatsMultipleItemsWithTheAmpersand() throws {
        XCTAssertEqual(stringify(obj: ["a": "b", "c": "d"]), "a=b&c=d")
    }
    
    func testStringifyEncodesDictIntoMultipleEntries() throws {
        let obj = ["a": ["b": "c"], "d": ["e": "f", "g": "h"]]
        XCTAssertEqual(stringify(obj: obj), "a[b]=c&d[e]=f&d[g]=h")
    }
    
    func testStringifyEncodesListIntoMultipleEntries() throws {
        let obj = ["a": [1, 2, 3], "b": ["q", "w", "e"]]
        XCTAssertEqual(stringify(obj: obj), "a[0]=1&a[1]=2&a[2]=3&b[0]=q&b[1]=w&b[2]=e")
    }
    
    func testStringifyEncodesNestedItemsIntoALongString() throws {
        let obj = ["_includes": [["favorites": ["_includes": ["user"]]]]]
        XCTAssertEqual(stringify(obj: obj), "_includes[0][favorites][_includes][0]=user")
    }
}

