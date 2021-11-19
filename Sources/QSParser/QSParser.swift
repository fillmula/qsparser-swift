import Foundation

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
            return ["\(genKey(items: items))=\(boolValue ? "true" : "false")"]
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
