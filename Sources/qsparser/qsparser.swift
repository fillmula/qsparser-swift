import Foundation

fileprivate func split(usingRegex pattern: String, str: String) -> [String] {
    let regex = try! NSRegularExpression(pattern: pattern)
    let matches = regex.matches(in: str, range: NSRange(0..<str.utf16.count))
    let ranges = [str.startIndex..<str.startIndex] + matches.map{Range($0.range, in: str)!} + [str.endIndex..<str.endIndex]
    return (0...matches.count).map {String(str[ranges[$0].upperBound..<ranges[$0+1].lowerBound])}
}

private func encodeUrl(str: String) -> String? {
    return str.addingPercentEncoding( withAllowedCharacters: NSCharacterSet.alphanumerics)
}

private func decodeUrl(str: String) -> String? {
    return str.removingPercentEncoding
}


public func stringify(_ obj: [String: Any]) -> String {
    var tokens: [String] = []
    for (key, value) in obj {
        tokens.append(contentsOf: genTokens(items: [key], value: value))
    }
    return tokens.joined(separator: "&")
}

private func genTokens(items: [String], value: Any?) -> [String] {
    var result: [String] = []
    if let nsValue = value as? NSNumber {
        if let boolValue = value as? Bool {
            return ["\(genKey(items: items))=\(boolValue ? "true" : "false")"]
        }else {
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
        return ["\(genKey(items: items))=\(encodeUrl(str: stringValue) ?? "")"]
    } else if let dateValue = value as? Date {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd hh:mm:ss"
        return ["\(genKey(items: items))=\(encodeUrl(str: df.string(from: dateValue)) ?? "")"]
    } else {
        return ["\(genKey(items: items))=null"]
    }
}

private func genKey(items: [String]) -> String {
    return "\(items[0])[\(items[1...].joined(separator: "]["))]".replacingOccurrences(of: "[]", with: "")
}

public func parse(_ qs: String) -> [String: Any] {
    var result: [String: Any] = [:]
    if qs == "" {
        return result
    }
    let tokens = qs.split(separator: "&")
    for token in tokens {
        let parts = String(token).split(separator: "=")
        var (k, v) = (String(parts[0]), String(parts[1]))
        if k.hasSuffix("]") {
            k.removeLast()
        }
        let items = split(usingRegex: "\\]?\\[", str: String(k))
        if items.count == 1 {
            result[items[0]] = decodeUrl(str: v)
        }
    }
    return result
}


 


//def assign_to_result(result: Union[dict[str, Any],
//                     list[Any]],
//                     items: list[str],
//                     value: str) -> Union[dict[str, Any], list[Any]]:
//    if len(items) == 1:
//        if isinstance(result, dict):
//            result[items[0]] = unquote(value)
//        else:
//            result.append(unquote(value))
//        return result
//    if isinstance(result, dict) and items[0] not in result:
//        if len(items) > 1 and items[1] == '0':
//            result[items[0]] = []
//        else:
//            result[items[0]] = {}
//    if isinstance(result, list) and int(items[0]) >= len(result):
//        if len(items) > 1 and items[1] == '0':
//            result.append([])
//        else:
//            result.append({})
//    if isinstance(result, dict):
//        assign_to_result(result[items[0]], items[1:], value)
//    else:
//        assign_to_result(result[int(items[0])], items[1:], value)
//    return result
