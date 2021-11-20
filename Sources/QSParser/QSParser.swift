import Foundation
import Combine

fileprivate func split(usingRegex pattern: String, str: String) -> [String] {
    let regex = try! NSRegularExpression(pattern: pattern)
    let matches = regex.matches(in: str, range: NSRange(0..<str.utf16.count))
    let ranges = [str.startIndex..<str.startIndex] + matches.map{Range($0.range, in: str)!} + [str.endIndex..<str.endIndex]
    return (0...matches.count).map {String(str[ranges[$0].upperBound..<ranges[$0+1].lowerBound])}
}

fileprivate func splitTokens(_ value: String) -> [String] {
    var key = value
    if key.hasSuffix("]") {
        key.removeLast()
    }
    return split(usingRegex: "\\]?\\[", str: key)
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
        let (key, value) = (parts[0], parts[1])
        let items = splitTokens(key)
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

private class QSEncoderTokens {

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

    func encodeDate(key codingKey: [CodingKey], value: Date) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let dateString = formatter.string(from: value)
        encode(key: codingKey, value: dateString)
    }

    func encodeString(key codingKey: [CodingKey], value: String) {
        switch value {
        case "nil":
            return encode(key: codingKey, value: "`nil`")
        case "null":
            return encode(key: codingKey, value: "`null`")
        case "Null":
            return encode(key: codingKey, value: "`Null`")
        case "NULL":
            return encode(key: codingKey, value: "`NULL`")
        case "None":
            return encode(key: codingKey, value: "`None`")
        default:
            return encode(key: codingKey, value: value)
        }
    }

    func generate() -> String {
        return tokens.joined(separator: "&")
    }
}

private class QSEncoderSingleValueContainer: SingleValueEncodingContainer {

    var tokens: QSEncoderTokens

    var codingPath: [CodingKey]

    init(codingPath: [CodingKey], to: QSEncoderTokens) {
        self.tokens = to
        self.codingPath = codingPath
    }

    func encodeNil() throws { }

    func encode(_ value: Bool) throws {
        tokens.encode(key: codingPath, value: value.description)
    }

    func encode(_ value: String) throws {
        tokens.encodeString(key: codingPath, value: value)
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
        if let date = value as? Date {
            tokens.encodeDate(key: codingPath, value: date)
        } else {
            let encoder = QSItemEncoder(to: tokens)
            encoder.codingPath = codingPath
            try value.encode(to: encoder)
        }
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

    private var tokens: QSEncoderTokens

    var codingPath: [CodingKey]

    init(codingPath: [CodingKey], to: QSEncoderTokens) {
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
        tokens.encodeString(key: codingPath + [nextIndexedKey()], value: value)
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
        if let date = value as? Date {
            tokens.encodeDate(key: codingPath + [nextIndexedKey()], value: date)
        } else {
            let encoder = QSItemEncoder(to: tokens)
            encoder.codingPath = codingPath + [nextIndexedKey()]
            try value.encode(to: encoder)
        }
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
        let encoder = QSItemEncoder(to: tokens)
        encoder.codingPath.append(nextIndexedKey())
        return encoder
    }
}

private class QSEncoderKeyedContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {

    private var tokens: QSEncoderTokens

    var codingPath: [CodingKey]

    init(codingPath: [CodingKey], to: QSEncoderTokens) {
        self.codingPath = codingPath
        self.tokens = to
    }

    func encodeNil(forKey key: Key) throws { }

    func encode(_ value: Bool, forKey key: Key) throws {
        tokens.encode(key: codingPath + [key], value: value.description)
    }

    func encode(_ value: String, forKey key: Key) throws {
        tokens.encodeString(key: codingPath + [key], value: value)
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
        if let date = value as? Date {
            tokens.encodeDate(key: codingPath + [key], value: date)
        } else {
            let encoder = QSItemEncoder(to: tokens)
            encoder.codingPath = codingPath + [key]
            try value.encode(to: encoder)
        }
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
        let encoder = QSItemEncoder(to: tokens)
        encoder.codingPath = codingPath + [key]
        return encoder
    }
}

private class QSItemEncoder: Encoder {

    init(to: QSEncoderTokens = QSEncoderTokens()) {
        self.tokens = to
    }

    var tokens: QSEncoderTokens

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
        let encoder = QSItemEncoder()
        try value.encode(to: encoder)
        return encoder.tokens.generate()
    }
}

private class QSDecoderTokens {

    init(_ value: String) {
        let pairs = value.split(separator: "&")
            .map { $0.split(separator: "=").map { String($0) } }
            .map { (splitTokens($0[0]), $0[1]) }
            .filter { isValidValue($0.1) }
        self.tokens = Dictionary(uniqueKeysWithValues: pairs)
    }

    var tokens: [[String]: String] = [:]

    func hasPath(_ codingPath: [CodingKey]) -> Bool {
        let key = codingPath.map { $0.stringValue }
        return tokens.contains { $0.key.starts(with: key) }
    }

    func getValue(_ codingPath: [CodingKey]) -> String {
        let key = codingPath.map { $0.stringValue }
        return tokens.removeValue(forKey: key)!
    }

    func isValidValue(_ str: String) -> Bool {
        switch str {
        case "nil":
            return false
        case "Null":
            return false
        case "null":
            return false
        case "NULL":
            return false
        case "None":
            return false
        default:
            return true
        }
    }

    func allKeys<Key: CodingKey>(at codingPath: [CodingKey]) -> [Key] {
        let path = codingPath.map { $0.stringValue }
        let pathCountPlusOne = path.count + 1
        var filtered = tokens.filter { $0.key.starts(with: path) }
            .map { $0.key.prefix(pathCountPlusOne) }
        filtered = Array(Set(filtered))
        return filtered.map { Key(stringValue: $0.last!)! }
    }

    func countForArrayAtCodingPath(_ codingPath: [CodingKey]) -> Int {
        let path = codingPath.map { $0.stringValue }
        let pathCountPlusOne = path.count + 1
        var filtered = tokens.filter { $0.key.starts(with: path) }
            .map { $0.key.prefix(pathCountPlusOne) }
        filtered = Array(Set(filtered))
        return filtered.count
    }

    func decodeDateValueAt(_ codingPath: [CodingKey]) -> Date {
        let value = getValue(codingPath)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.date(from: urlDecode(value))!
    }

    func decodeStringValue(_ value: String) -> String {
        let decoded = urlDecode(value)
        switch decoded {
        case "`nil`":
            return "nil"
        case "`null`":
            return "null"
        case "`Null`":
            return "Null"
        case "`NULL`":
            return "NULL"
        case "`None`":
            return "None"
        default:
            return decoded
        }
    }

    func decodeBoolValue(_ value: String) -> Bool {
        switch value {
        case "true":
            return true
        case "True":
            return true
        case "TRUE":
            return true
        case "YES":
            return true
        case "false":
            return false
        case "False":
            return false
        case "FALSE":
            return false
        case "NO":
            return false
        default:
            return false
        }
    }
}

class QSDecoderKeyedContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {

    fileprivate init(codingPath: [CodingKey], tokens: QSDecoderTokens) {
        self.codingPath = codingPath
        self.tokens = tokens
        self.allKeys = self.tokens.allKeys(at: codingPath)
    }

    fileprivate var tokens: QSDecoderTokens

    var codingPath: [CodingKey]

    var allKeys: [Key]

    func contains(_ key: Key) -> Bool {
        return tokens.hasPath(codingPath + [key])
    }

    func decodeNil(forKey key: Key) throws -> Bool {
        return false
    }

    func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
        return tokens.decodeBoolValue(tokens.getValue(codingPath + [key]))
    }

    func decode(_ type: String.Type, forKey key: Key) throws -> String {
        return tokens.decodeStringValue(tokens.getValue(codingPath + [key]))
    }

    func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
        return Double(tokens.getValue(codingPath + [key]))!
    }

    func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
        return Float(tokens.getValue(codingPath + [key]))!
    }

    func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
        return Int(tokens.getValue(codingPath + [key]))!
    }

    func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
        return Int8(tokens.getValue(codingPath + [key]))!
    }

    func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
        return Int16(tokens.getValue(codingPath + [key]))!
    }

    func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
        return Int32(tokens.getValue(codingPath + [key]))!
    }

    func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
        return Int64(tokens.getValue(codingPath + [key]))!
    }

    func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
        return UInt(tokens.getValue(codingPath + [key]))!
    }

    func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
        return UInt8(tokens.getValue(codingPath + [key]))!
    }

    func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
        return UInt16(tokens.getValue(codingPath + [key]))!
    }

    func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
        return UInt32(tokens.getValue(codingPath + [key]))!
    }

    func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
        return UInt64(tokens.getValue(codingPath + [key]))!
    }

    func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T : Decodable {
        if T.self == Date.self {
            return tokens.decodeDateValueAt(codingPath + [key]) as! T
        } else {
            let decoder = QSItemDecoder(tokens)
            decoder.codingPath = codingPath + [key]
            return try T(from: decoder)
        }
    }

    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
        let container = QSDecoderKeyedContainer<NestedKey>(codingPath: codingPath + [key], tokens: tokens)
        return KeyedDecodingContainer(container)
    }

    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        let container = QSDecoderUnkeyedContainer(codingPath: codingPath + [key], tokens: tokens)
        return container
    }

    func superDecoder() throws -> Decoder {
        let superKey = Key(stringValue: "super")!
        return try superDecoder(forKey: superKey)
    }

    func superDecoder(forKey key: Key) throws -> Decoder {
        let decoder = QSItemDecoder(tokens)
        decoder.codingPath = codingPath + [key]
        return decoder
    }
}

class QSDecoderUnkeyedContainer: UnkeyedDecodingContainer {

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
        let nextCodingKey = IndexedCodingKey(intValue: currentIndex)!
        currentIndex += 1
        if currentIndex == count {
            isAtEnd = true
        }
        return nextCodingKey
    }

    fileprivate init(codingPath: [CodingKey], tokens: QSDecoderTokens) {
        self.codingPath = codingPath
        self.tokens = tokens
        self.currentIndex = 0
        self.isAtEnd = false
        self.count = tokens.countForArrayAtCodingPath(codingPath)
    }

    fileprivate var tokens: QSDecoderTokens

    var codingPath: [CodingKey]

    var count: Int?

    var isAtEnd: Bool

    var currentIndex: Int

    func decodeNil() throws -> Bool {
        return true
    }

    func decode(_ type: Bool.Type) throws -> Bool {
        return tokens.decodeBoolValue(tokens.getValue(codingPath + [nextIndexedKey()]))
    }

    func decode(_ type: String.Type) throws -> String {
        return tokens.decodeStringValue(tokens.getValue(codingPath + [nextIndexedKey()]))
    }

    func decode(_ type: Double.Type) throws -> Double {
        let string = tokens.getValue(codingPath + [nextIndexedKey()])
        return Double(string)!
    }

    func decode(_ type: Float.Type) throws -> Float {
        let string = tokens.getValue(codingPath + [nextIndexedKey()])
        return Float(string)!
    }

    func decode(_ type: Int.Type) throws -> Int {
        let string = tokens.getValue(codingPath + [nextIndexedKey()])
        return Int(string)!
    }

    func decode(_ type: Int8.Type) throws -> Int8 {
        let string = tokens.getValue(codingPath + [nextIndexedKey()])
        return Int8(string)!
    }

    func decode(_ type: Int16.Type) throws -> Int16 {
        let string = tokens.getValue(codingPath + [nextIndexedKey()])
        return Int16(string)!
    }

    func decode(_ type: Int32.Type) throws -> Int32 {
        let string = tokens.getValue(codingPath + [nextIndexedKey()])
        return Int32(string)!
    }

    func decode(_ type: Int64.Type) throws -> Int64 {
        let string = tokens.getValue(codingPath + [nextIndexedKey()])
        return Int64(string)!
    }

    func decode(_ type: UInt.Type) throws -> UInt {
        let string = tokens.getValue(codingPath + [nextIndexedKey()])
        return UInt(string)!
    }

    func decode(_ type: UInt8.Type) throws -> UInt8 {
        let string = tokens.getValue(codingPath + [nextIndexedKey()])
        return UInt8(string)!
    }

    func decode(_ type: UInt16.Type) throws -> UInt16 {
        let string = tokens.getValue(codingPath + [nextIndexedKey()])
        return UInt16(string)!
    }

    func decode(_ type: UInt32.Type) throws -> UInt32 {
        let string = tokens.getValue(codingPath + [nextIndexedKey()])
        return UInt32(string)!
    }

    func decode(_ type: UInt64.Type) throws -> UInt64 {
        let string = tokens.getValue(codingPath + [nextIndexedKey()])
        return UInt64(string)!
    }

    func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
        if T.self == Date.self {
            return tokens.decodeDateValueAt(codingPath + [nextIndexedKey()]) as! T
        } else {
            let decoder = QSItemDecoder(tokens)
            decoder.codingPath = codingPath + [nextIndexedKey()]
            return try T.init(from: decoder)
        }
    }

    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
        let container = QSDecoderKeyedContainer<NestedKey>(codingPath: codingPath + [nextIndexedKey()], tokens: tokens)
        return KeyedDecodingContainer(container)
    }

    func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        return QSDecoderUnkeyedContainer(codingPath: codingPath + [nextIndexedKey()], tokens: tokens)
    }

    func superDecoder() throws -> Decoder {
        let decoder = QSItemDecoder(tokens)
        decoder.codingPath = codingPath + [nextIndexedKey()]
        return decoder
    }
}

class QSDecoderSingleValueContainer: SingleValueDecodingContainer {

    fileprivate var tokens: QSDecoderTokens

    var codingPath: [CodingKey]

    fileprivate init(codingPath: [CodingKey], tokens: QSDecoderTokens) {
        self.tokens = tokens
        self.codingPath = codingPath
    }

    func decodeNil() -> Bool {
        return false
    }

    func decode(_ type: Bool.Type) throws -> Bool {
        return tokens.decodeBoolValue(tokens.getValue(codingPath))
    }

    func decode(_ type: String.Type) throws -> String {
        return tokens.decodeStringValue(tokens.getValue(codingPath))
    }

    func decode(_ type: Double.Type) throws -> Double {
        let string = tokens.getValue(codingPath)
        return Double(string)!
    }

    func decode(_ type: Float.Type) throws -> Float {
        let string = tokens.getValue(codingPath)
        return Float(string)!
    }

    func decode(_ type: Int.Type) throws -> Int {
        let string = tokens.getValue(codingPath)
        return Int(string)!
    }

    func decode(_ type: Int8.Type) throws -> Int8 {
        let string = tokens.getValue(codingPath)
        return Int8(string)!
    }

    func decode(_ type: Int16.Type) throws -> Int16 {
        let string = tokens.getValue(codingPath)
        return Int16(string)!
    }

    func decode(_ type: Int32.Type) throws -> Int32 {
        let string = tokens.getValue(codingPath)
        return Int32(string)!
    }

    func decode(_ type: Int64.Type) throws -> Int64 {
        let string = tokens.getValue(codingPath)
        return Int64(string)!
    }

    func decode(_ type: UInt.Type) throws -> UInt {
        let string = tokens.getValue(codingPath)
        return UInt(string)!
    }

    func decode(_ type: UInt8.Type) throws -> UInt8 {
        let string = tokens.getValue(codingPath)
        return UInt8(string)!
    }

    func decode(_ type: UInt16.Type) throws -> UInt16 {
        let string = tokens.getValue(codingPath)
        return UInt16(string)!
    }

    func decode(_ type: UInt32.Type) throws -> UInt32 {
        let string = tokens.getValue(codingPath)
        return UInt32(string)!
    }

    func decode(_ type: UInt64.Type) throws -> UInt64 {
        let string = tokens.getValue(codingPath)
        return UInt64(string)!
    }

    func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
        if T.self == Date.self {
            return tokens.decodeDateValueAt(codingPath) as! T
        } else {
            let decoder = QSItemDecoder(tokens)
            decoder.codingPath = codingPath
            return try T.init(from: decoder)
        }
    }
}

public class QSItemDecoder: Decoder {

    fileprivate var tokens: QSDecoderTokens

    fileprivate init(_ from: QSDecoderTokens) {
        tokens = from
    }

    public var codingPath: [CodingKey] = []

    public var userInfo: [CodingUserInfoKey : Any] = [:]

    public func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
        let container = QSDecoderKeyedContainer<Key>(codingPath: codingPath, tokens: tokens)
        return KeyedDecodingContainer(container)
    }

    public func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        return QSDecoderUnkeyedContainer(codingPath: codingPath, tokens: tokens)
    }

    public func singleValueContainer() throws -> SingleValueDecodingContainer {
        return QSDecoderSingleValueContainer(codingPath: codingPath, tokens: tokens)
    }
}

public class QSDecoder: TopLevelDecoder {

    public typealias Input = String

    public func decode<T>(_ type: T.Type, from: Input) throws -> T where T : Decodable {
        let decoder = QSItemDecoder(QSDecoderTokens(from))
        return try T.init(from: decoder)
    }
}
