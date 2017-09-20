//
//  SQLHelpers.swift
//  GeoCache
//
//  Created by Chris Woodard on 7/26/17.
//  Copyright © 2017 UsefulSoft. All rights reserved.
//

import Foundation

func stringFrom(cStr:UnsafePointer<Int8>?) -> String {
    if let cString = cStr {
        return String(cString:cString)
    }
    return ""
}

func escaped(string:String) -> String {
    return string.replacingOccurrences(of: "'", with: "''")
}

func unescaped(string:String) -> String {
    return string.replacingOccurrences(of: "''", with: "'")
}

func urlEncoded(string:String) -> String {
    let charSet = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".,~-="))
    return string.addingPercentEncoding(withAllowedCharacters: charSet)!
}

func iso6801(date:Date) -> String {
    let fmtr = DateFormatter()
    fmtr.dateFormat = "yyyy-MM-dd'T'HH:mm:SS.SS"
    return fmtr.string(from: date)
}

func date(iso8601:String) -> Date? {
    let fmtr = DateFormatter()
    fmtr.dateFormat = "yyyy-MM-dd'T'HH:mm:SS.SS"
    return fmtr.date(from: iso8601)
}

func dict(json:String) -> [String:Any]? {
    if let theData = json.data(using: .utf8) {
        if let theDict = try! JSONSerialization.jsonObject(with: theData, options: .mutableContainers) as? [String:Any] {
            return theDict
        }
    }
    return nil
}

func array(json:String) -> [Any]? {
    if let theData = json.data(using: .utf8) {
        if let theArray = try! JSONSerialization.jsonObject(with: theData, options: .mutableContainers) as? [Any] {
            return theArray
        }
    }
    return nil
}

