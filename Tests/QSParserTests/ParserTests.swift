import XCTest
@testable import QSParser


final class ParserTests: XCTestCase {

    func testParseDecodesIntIntoString() throws {
        XCTAssertEqual(parse("a=5") as! [String:String], ["a": "5"])
    }

    func testParseDecodesFloatIntoString() throws {
        XCTAssertEqual(parse("a=5.5") as! [String:String], ["a": "5.5"])
    }

    func testParseDecodesTrueIntoString() throws {
        XCTAssertEqual(parse("a=true") as! [String:String], ["a": "true"])
    }

    func testParseDecodesFalseIntoString() throws {
        XCTAssertEqual(parse("a=false") as! [String:String], ["a": "false"])
    }

    func testParseDecodesStringIntoString() throws {
        XCTAssertEqual(parse("a=b") as! [String:String], ["a": "b"])
    }

    func testParseDecodesWhitespaces() throws {
        XCTAssertEqual(parse("a=b%20c") as! [String:String], ["a": "b c"])
    }

    func testParseDecodesSpecialChars() throws {
        XCTAssertEqual(parse("a=%E4%BF%8A") as! [String:String], ["a": "俊"])
    }

    func testParseDecodesMultipleItemsToASingleObject() throws {
        XCTAssertEqual(parse("a=b&c=d") as! [String:String], ["a": "b", "c": "d"])
    }

    func testParseDecodesEntriesIntoMultipleNestedObjects() throws {
        XCTAssertEqual(parse("a[b]=c&d[e]=f&d[g]=h") as! [String:[String:String]], ["a": ["b": "c"], "d": ["e": "f", "g": "h"]])
    }

    func testParseDecodesListIntoMultipleNestedObject() throws {
        let expected: [String:[String]] = ["a": ["1", "2", "3"], "b": ["q" ,"w", "e"]]
        XCTAssertEqual(parse("a[0]=1&a[1]=2&a[2]=3&b[0]=q&b[1]=w&b[2]=e") as! [String:[String]], expected)
    }

    func testParseDecodesDictsInLists() throws {
        let qs = "a[0][n][0]=John&a[0][n][1]=15&a[1][n][0]=Peter&a[1][n][1]=18&b[0][n][0]=Jack&b[0][n][1]=17"
        let expected: [String:[[String: [String]]]] = [
            "a": [["n": ["John", "15"]], ["n": ["Peter", "18"]]],
            "b": [["n": ["Jack", "17"]]]
        ]
        XCTAssertEqual(parse(qs) as! [String:[[String: [String]]]], expected)
    }

    func testParseDecodesALongStringIntoNestedItems() throws {
        let original = "_includes[0][favorites][_includes][0]=user"
        let expected: [String:[[String:[String:[String]]]]] = ["_includes": [["favorites": ["_includes": ["user"]]]]]
        XCTAssertEqual(parse(original) as! [String:[[String:[String:[String]]]]], expected)
    }

    func testParseDecodesEmptyStringIntoEmptyObject() throws {
        let original = ""
        let expected: [String:String] = [:]
        XCTAssertEqual(parse(original) as! [String:String], expected)
    }

    func testParseDecodesNullIntoNil() throws {
        XCTAssertEqual(parse("abc=null") as! [String: String?], ["abc": nil])
        XCTAssertEqual(parse("abc=Null") as! [String: String?], ["abc": nil])
        XCTAssertEqual(parse("abc=NULL") as! [String: String?], ["abc": nil])
        XCTAssertEqual(parse("abc=nil") as! [String: String?], ["abc": nil])
        XCTAssertEqual(parse("abc=None") as! [String: String?], ["abc": nil])
    }

    func testParseDecodesNullRepresentingStringIntoNullString() throws {
        XCTAssertEqual(parse("abc=%60null%60") as! [String: String?], ["abc": "null"])
        XCTAssertEqual(parse("abc=%60Null%60") as! [String: String?], ["abc": "Null"])
        XCTAssertEqual(parse("abc=%60NULL%60") as! [String: String?], ["abc": "NULL"])
    }

    func testParseDecodesNilRepresentingStringIntoNilString() throws {
        XCTAssertEqual(parse("abc=%60nil%60") as! [String: String?], ["abc": "nil"])
    }

    func testParseDecodesNoneRepresentingStringIntoNoneString() throws {
        XCTAssertEqual(parse("abc=%60None%60") as! [String: String?], ["abc": "None"])
    }
}
