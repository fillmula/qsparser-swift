import XCTest
@testable import qsparser


final class parserTests: XCTestCase {
    func testParseDecodesIntIntoString() throws {
        XCTAssertEqual(parse(qs: "a=5") as! [String:String], ["a": "5"])
    }
    func testParseDecodesFloatIntoString() throws {
        XCTAssertEqual(parse(qs: "a=5.5") as! [String:String], ["a": "5.5"])
    }
    func testParseDecodesTrueIntoString() throws {
        XCTAssertEqual(parse(qs: "a=true") as! [String:String], ["a": "true"])
    }
    func testParseDecodesFalseIntoString() throws {
        XCTAssertEqual(parse(qs: "a=false") as! [String:String], ["a": "false"])
    }
    func testParseDecodesStringIntoString() throws {
        XCTAssertEqual(parse(qs: "a=b") as! [String:String], ["a": "b"])
    }
    func testParseDecodesWhitespaces() throws {
        XCTAssertEqual(parse(qs: "a=b%20c") as! [String:String], ["a": "b c"])
    }
    func testParseDecodesSpecialChars() throws {
        XCTAssertEqual(parse(qs: "a=%E4%BF%8A") as! [String:String], ["a": "俊"])
    }
    func testParseDecodesMultipleItemsToASingleObject() throws {
        XCTAssertEqual(parse(qs: "a=b&c=d") as! [String:String], ["a": "b", "c": "d"])
    }
    func testParseDecodesEntriesIntoMultipleNestedObjects() throws {
        XCTAssertEqual(parse(qs: "a[b]=c&d[e]=f&d[g]=h") as! [String:[String:String]], ["a": ["b": "c"], "d": ["e": "f", "g": "h"]])
    }
    func test_parse_decodes_list_into_multiple_nested_object() throws {
        let expected: [String:[String]] = ["a": ["1", "2", "3"], "b": ["q" ,"w", "e"]]
        XCTAssertEqual(parse(qs: "a[0]=1&a[1]=2&a[2]=3&b[0]=q&b[1]=w&b[2]=e") as! [String:[String]], expected)
    }
    func testParseDecodesDictsInLists() throws {
        let qs = "a[0][n][0]=John&a[0][n][1]=15&a[1][n][0]=Peter&a[1][n][1]=18&b[0][n][0]=Jack&b[0][n][1]=17"
        let expected: [String:[[String: [String]]]] = [
            "a": [["n": ["John", "15"]], ["n": ["Peter", "18"]]],
            "b": [["n": ["Jack", "17"]]]
        ]
        XCTAssertEqual(parse(qs: qs) as! [String:[[String: [String]]]], expected)
    }
    func testParseDecodesALongStringIntoNestedItems() throws {
        let original = "_includes[0][favorites][_includes][0]=user"
        let expected: [String:[[String:[String:[String]]]]] = ["_includes": [["favorites": ["_includes": ["user"]]]]]
        XCTAssertEqual(parse(qs: original) as! [String:[[String:[String:[String]]]]], expected)
    }
    func testParseDecodesEmptyStringIntoEmptyObject() throws {
        let original = ""
        let expected: [String:String] = [:]
        XCTAssertEqual(parse(qs: original) as! [String:String], expected)
    }


}

