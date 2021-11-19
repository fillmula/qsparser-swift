import Foundation
import Combine

fileprivate func split(usingRegex pattern: String, str: String) -> [String] {
    let regex = try! NSRegularExpression(pattern: pattern)
    let matches = regex.matches(in: str, range: NSRange(0..<str.utf16.count))
    let ranges = [str.startIndex..<str.startIndex] + matches.map{Range($0.range, in: str)!} + [str.endIndex..<str.endIndex]
    return (0...matches.count).map {String(str[ranges[$0].upperBound..<ranges[$0+1].lowerBound])}
}

fileprivate func urlEncode(_ str: String) -> String {
    return str.addingPercentEncoding(withAllowedCharacters: NSCharacterSet.alphanumerics)!
}

fileprivate func urlDecode(_ str: String) -> String {
    return str.removingPercentEncoding!
}

public func stringify(_ obj: [String: Any]) -> String {
    var tokens: [String] = []
    for (key, value) in obj {
        tokens.append(contentsOf: genTokens(items: [key], value: value))
    }
    return tokens.joined(separator: "&")
}

fileprivate func genTokens(items: [String], value: Any?) -> [String] {
    var result: [String] = []
    if let nsValue = value as? NSNumber {
        if let boolValue = value as? Bool {
            return ["\(genKey(items: items))=\(boolValue.description)"]
        } else {
            return ["\(genKey(items: items))=\(nsValue.stringValue)"]
        }
    } else if let listValue = value as? [Any] {
        for (i, v) in listValue.enumerated() {
            result.append(contentsOf: genTokens(items: items + [String(i)], value: v))
        }
        return result
    } else if let dictValue = value as? [String: Any] {
        for(k, v) in dictValue {
            result.append(contentsOf: genTokens(items: items + [String(k)], value: v))
        }
        return result
    } else if let stringValue = value as? String {
        return ["\(genKey(items: items))=\(urlEncode(stringValue))"]
    } else if let dateValue = value as? Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let dateString = formatter.string(from: dateValue)
        return ["\(genKey(items: items))=\(urlEncode(dateString))"]
    } else {
        return ["\(genKey(items: items))=null"]
    }
}

fileprivate func genKey(items: [String]) -> String {
    return "\(items[0])[\(items[1...].joined(separator: "]["))]".replacingOccurrences(of: "[]", with: "")
}

public func parse(_ qs: String) -> [String: Any] {
    var result: [String: Any] = [:]
    if qs == "" {
        return result
    }
    let tokens = qs.split(separator: "&").map {String($0)}
    for token in tokens {
        let parts = token.split(separator: "=").map {String($0)}
        var (key, value) = (parts[0], parts[1])
        if key.hasSuffix("]") {
            key.removeLast()
        }
        let items = split(usingRegex: "\\]?\\[", str: key)
        result = combineResult(result, items, value) as! [String : Any]
    }
    return result
}

fileprivate func combineResult(_ original: Any, _ items: [String], _ value: String) -> Any {
    var result = original
    if items.count == 1 {
        if let dict = result as? [String:Any] {
            return dict.merging([items[0]: urlDecode(value)]) { $1 }
        } else if let array = result as? [Any] {
            return array + [urlDecode(value)]
        } else {
            return result
        }
    }
    if let dict = result as? [String:Any], dict[items[0]] == nil {
        if items.count > 1, items[1] == "0" {
            result = dict.merging([items[0]: []]) {$1}
        } else {
            result = dict.merging([items[0]: [:]]) {$1}
        }
    }
    if let array = result as? [Any], Int(items[0])! >= array.count {
        if items.count > 1, items[1] == "0" {
            result = array + [[]]
        } else {
            result = array + [[:]]
        }
    }
    if let dict = result as? [String:Any] {
        return dict.merging([
            items[0]: combineResult(dict[items[0]]!, Array(items.dropFirst()), value)
        ]) {$1}
    } else if let array = result as? [Any] {
        var retval = array
        retval[Int(items[0])!] = combineResult(array[Int(items[0])!], Array(items.dropFirst()), value)
        return retval
    } else {
        return result
    }
}

private class QSTokens {

    var tokens: [String] = []

    func encode(key codingKey: [CodingKey], value: String, noEscape: Bool = false) {
        let count = codingKey.count
        if count == 0 {
            tokens.append(value)
        } else {
            let first = codingKey[0].stringValue
            let escapedValue = noEscape ? value : urlEncode(value)
            if count == 1 {
                tokens.append("\(first)=\(escapedValue)")
            } else {
                let rest = codingKey[1...].map({ "[\($0.stringValue)]" }).joined()
                tokens.append("\(first)\(rest)=\(escapedValue)")
            }
        }
    }

    func generate() -> String {
        return tokens.joined(separator: "&")
    }
}

private class QSEncoderSingleValueContainer: SingleValueEncodingContainer {

    var tokens: QSTokens

    var codingPath: [CodingKey]

    init(codingPath: [CodingKey], to: QSTokens) {
        self.tokens = to
        self.codingPath = codingPath
    }

    func encodeNil() throws { }

    func encode(_ value: Bool) throws {
        tokens.encode(key: codingPath, value: value.description)
    }

    func encode(_ value: String) throws {
        tokens.encode(key: codingPath, value: value)
    }

    func encode(_ value: Double) throws {
        tokens.encode(key: codingPath, value: value.description, noEscape: true)
    }

    func encode(_ value: Float) throws {
        tokens.encode(key: codingPath, value: value.description, noEscape: true)
    }

    func encode(_ value: Int) throws {
        tokens.encode(key: codingPath, value: value.description, noEscape: true)
    }

    func encode(_ value: Int8) throws {
        tokens.encode(key: codingPath, value: value.description, noEscape: true)
    }

    func encode(_ value: Int16) throws {
        tokens.encode(key: codingPath, value: value.description, noEscape: true)
    }

    func encode(_ value: Int32) throws {
        tokens.encode(key: codingPath, value: value.description, noEscape: true)
    }

    func encode(_ value: Int64) throws {
        tokens.encode(key: codingPath, value: value.description, noEscape: true)
    }

    func encode(_ value: UInt) throws {
        tokens.encode(key: codingPath, value: value.description, noEscape: true)
    }

    func encode(_ value: UInt8) throws {
        tokens.encode(key: codingPath, value: value.description, noEscape: true)
    }

    func encode(_ value: UInt16) throws {
        tokens.encode(key: codingPath, value: value.description, noEscape: true)
    }

    func encode(_ value: UInt32) throws {
        tokens.encode(key: codingPath, value: value.description, noEscape: true)
    }

    func encode(_ value: UInt64) throws {
        tokens.encode(key: codingPath, value: value.description, noEscape: true)
    }

    func encode<T>(_ value: T) throws where T : Encodable {
        let encoder = QSRootEncoder(to: tokens)
        encoder.codingPath = codingPath
        try value.encode(to: encoder)
    }
}

private class QSEncoderUnkeyedContainer: UnkeyedEncodingContainer {

    private struct IndexedCodingKey: CodingKey {
        let intValue: Int?
        let stringValue: String

        init?(intValue: Int) {
            self.intValue = intValue
            self.stringValue = intValue.description
        }

        init?(stringValue: String) {
            return nil
        }
    }

    private func nextIndexedKey() -> CodingKey {
         let nextCodingKey = IndexedCodingKey(intValue: count)!
         count += 1
         return nextCodingKey
     }

    var count: Int = 0

    private var tokens: QSTokens

    var codingPath: [CodingKey]

    init(codingPath: [CodingKey], to: QSTokens) {
        self.codingPath = codingPath
        self.tokens = to
    }

    func encodeNil() throws {
        tokens.encode(key: codingPath + [nextIndexedKey()], value: "null")
    }

    func encode(_ value: Bool) throws {
        tokens.encode(key: codingPath + [nextIndexedKey()], value: value.description)
    }

    func encode(_ value: String) throws {
        tokens.encode(key: codingPath + [nextIndexedKey()], value: value)
    }

    func encode(_ value: Double) throws {
        tokens.encode(key: codingPath + [nextIndexedKey()], value: value.description, noEscape: true)
    }

    func encode(_ value: Float) throws {
        tokens.encode(key: codingPath + [nextIndexedKey()], value: value.description, noEscape: true)
    }

    func encode(_ value: Int) throws {
        tokens.encode(key: codingPath + [nextIndexedKey()], value: value.description, noEscape: true)
    }

    func encode(_ value: Int8) throws {
        tokens.encode(key: codingPath + [nextIndexedKey()], value: value.description, noEscape: true)
    }

    func encode(_ value: Int16) throws {
        tokens.encode(key: codingPath + [nextIndexedKey()], value: value.description, noEscape: true)
    }

    func encode(_ value: Int32) throws {
        tokens.encode(key: codingPath + [nextIndexedKey()], value: value.description, noEscape: true)
    }

    func encode(_ value: Int64) throws {
        tokens.encode(key: codingPath + [nextIndexedKey()], value: value.description, noEscape: true)
    }

    func encode(_ value: UInt) throws {
        tokens.encode(key: codingPath + [nextIndexedKey()], value: value.description, noEscape: true)
    }

    func encode(_ value: UInt8) throws {
        tokens.encode(key: codingPath + [nextIndexedKey()], value: value.description, noEscape: true)
    }

    func encode(_ value: UInt16) throws {
        tokens.encode(key: codingPath + [nextIndexedKey()], value: value.description, noEscape: true)
    }

    func encode(_ value: UInt32) throws {
        tokens.encode(key: codingPath + [nextIndexedKey()], value: value.description, noEscape: true)
    }

    func encode(_ value: UInt64) throws {
        tokens.encode(key: codingPath + [nextIndexedKey()], value: value.description, noEscape: true)
    }

    func encode<T>(_ value: T) throws where T : Encodable {
        let encoder = QSRootEncoder(to: tokens)
        encoder.codingPath = codingPath + [nextIndexedKey()]
        try value.encode(to: encoder)
    }

    func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
        let container = QSEncoderKeyedContainer<NestedKey>(codingPath: codingPath + [nextIndexedKey()], to: tokens)
        return KeyedEncodingContainer(container)
    }

    func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        return QSEncoderUnkeyedContainer(
            codingPath: codingPath + [nextIndexedKey()],
            to: tokens)
    }

    func superEncoder() -> Encoder {
        let encoder = QSRootEncoder(to: tokens)
        encoder.codingPath.append(nextIndexedKey())
        return encoder
    }
}

private class QSEncoderKeyedContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {

    private var tokens: QSTokens

    var codingPath: [CodingKey]

    init(codingPath: [CodingKey], to: QSTokens) {
        self.codingPath = codingPath
        self.tokens = to
    }

    func encodeNil(forKey key: Key) throws { }

    func encode(_ value: Bool, forKey key: Key) throws {
        tokens.encode(key: codingPath + [key], value: value.description)
    }

    func encode(_ value: String, forKey key: Key) throws {
        tokens.encode(key: codingPath + [key], value: value)
    }

    func encode(_ value: Double, forKey key: Key) throws {
        tokens.encode(key: codingPath + [key], value: value.description, noEscape: true)
    }

    func encode(_ value: Float, forKey key: Key) throws {
        tokens.encode(key: codingPath + [key], value: value.description, noEscape: true)
    }

    func encode(_ value: Int, forKey key: Key) throws {
        tokens.encode(key: codingPath + [key], value: value.description, noEscape: true)
    }

    func encode(_ value: Int8, forKey key: Key) throws {
        tokens.encode(key: codingPath + [key], value: value.description, noEscape: true)
    }

    func encode(_ value: Int16, forKey key: Key) throws {
        tokens.encode(key: codingPath + [key], value: value.description, noEscape: true)
    }

    func encode(_ value: Int32, forKey key: Key) throws {
        tokens.encode(key: codingPath + [key], value: value.description, noEscape: true)
    }

    func encode(_ value: Int64, forKey key: Key) throws {
        tokens.encode(key: codingPath + [key], value: value.description, noEscape: true)
    }

    func encode(_ value: UInt, forKey key: Key) throws {
        tokens.encode(key: codingPath + [key], value: value.description, noEscape: true)
    }

    func encode(_ value: UInt8, forKey key: Key) throws {
        tokens.encode(key: codingPath + [key], value: value.description, noEscape: true)
    }

    func encode(_ value: UInt16, forKey key: Key) throws {
        tokens.encode(key: codingPath + [key], value: value.description, noEscape: true)
    }

    func encode(_ value: UInt32, forKey key: Key) throws {
        tokens.encode(key: codingPath + [key], value: value.description, noEscape: true)
    }

    func encode(_ value: UInt64, forKey key: Key) throws {
        tokens.encode(key: codingPath + [key], value: value.description, noEscape: true)
    }

    func encode<T>(_ value: T, forKey key: Key) throws where T : Encodable {
        let encoder = QSRootEncoder(to: tokens)
        encoder.codingPath = codingPath + [key]
        try value.encode(to: encoder)
    }

    func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
        let container = QSEncoderKeyedContainer<NestedKey>(codingPath: codingPath + [key], to: tokens)
        return KeyedEncodingContainer(container)
    }

    func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        return QSEncoderUnkeyedContainer(codingPath: codingPath + [key], to: tokens)
    }

    func superEncoder() -> Encoder {
        let superKey = Key(stringValue: "super")!
        return superEncoder(forKey: superKey)
    }

    func superEncoder(forKey key: Key) -> Encoder {
        let encoder = QSRootEncoder(to: tokens)
        encoder.codingPath = codingPath + [key]
        return encoder
    }
}

private class QSRootEncoder: Encoder {

    init(to: QSTokens = QSTokens()) {
        self.tokens = to
    }

    var tokens: QSTokens

    var codingPath: [CodingKey] = []

    var userInfo: [CodingUserInfoKey : Any] = [:]

    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key : CodingKey {
        let container = QSEncoderKeyedContainer<Key>(codingPath: codingPath, to: tokens)
        return KeyedEncodingContainer(container)
    }

    func unkeyedContainer() -> UnkeyedEncodingContainer {
        return QSEncoderUnkeyedContainer(codingPath: codingPath, to: tokens)
    }

    func singleValueContainer() -> SingleValueEncodingContainer {
        return QSEncoderSingleValueContainer(codingPath: codingPath, to: tokens)
    }
}

public class QSEncoder: TopLevelEncoder {

    public typealias Output = String

    public func encode<T>(_ value: T) throws -> Output where T : Encodable {
        let encoder = QSRootEncoder()
        try value.encode(to: encoder)
        return encoder.tokens.generate()
    }
}

//public class QSDecoder: TopLevelDecoder {
//
//    public typealias Input = String
//
//    public func decode<T>(_ type: T.Type, from: Input) throws -> T where T : Decodable {
//        <#code#>
//    }
//
//}
