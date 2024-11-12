//
//  main.swift
//  XCStringsParser
//
//  Created by Marcel Hasselaar on 2024-11-12.
//

import Foundation
import OrderedCollections


struct Localization: Codable {
    let sourceLanguage: String
    let strings: [String: LocalizedString]
}

struct LocalizedString: Codable {
    let comment: String?
    let extractionState: String
    var localizations: [String: LocalizationValue]
}

struct LocalizationValue: Codable {
    let stringUnit: StringUnit
}

struct StringUnit: Codable {
    let state: String
    let value: String
}

func parseJSON(from filePath: String) -> Localization? {
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else { return nil }
    let decoder = JSONDecoder()
    return try? decoder.decode(Localization.self, from: data)
}

func convertToCSV(localization: Localization, to filePath: String, languages: [String]? = nil) {
    let localizedLanguages = Set(localization.strings.first!.value.localizations.keys)
    let filteredLocalizedLanguages = languages.map { OrderedSet($0) }.map { localizedLanguages.intersection($0) } ?? localizedLanguages
    var csvString = "Key|" + filteredLocalizedLanguages.joined(separator: "|") + "|Comment\n"
    for (key, localizedString) in localization.strings.sorted(by: { $0.key < $1.key }) {
        let comment = localizedString.comment ?? ""
        var line = "\(key)|"
        for lang in filteredLocalizedLanguages {
            line += "\(localizedString.localizations[lang]?.stringUnit.value ?? "")|"
        }
        line += "\(comment)\n"
        csvString.append(line)
    }
    do {
        try csvString.write(toFile: filePath, atomically: true, encoding: .utf8)
        print("File written to \(filePath).")
    } catch {
        print("Error writing CSV to \(filePath): \(error)")
    }
}

func parseCSV(from filePath: String) -> Localization? {
    guard let csvString = try? String(contentsOf: URL(fileURLWithPath: filePath), encoding: .utf8) else { return nil }
    var lines = csvString.components(separatedBy: "\n")
    lines.removeFirst() // Remove header line

    var strings: [String: LocalizedString] = [:]

    for line in lines {
        let columns = line.components(separatedBy: ",")
        guard columns.count == 6 else { continue }

        let key = columns[0]
        let comment = columns[1]
        let extractionState = columns[2]
        let language = columns[3]
        let state = columns[4]
        let value = columns[5]

        let stringUnit = StringUnit(state: state, value: value)
        let localizationValue = LocalizationValue(stringUnit: stringUnit)

        if strings[key] == nil {
            strings[key] = LocalizedString(comment: comment.isEmpty ? nil : comment, extractionState: extractionState, localizations: [language: localizationValue])
        } else {
            strings[key]?.localizations[language] = localizationValue
        }
    }

    return Localization(sourceLanguage: "en", strings: strings)
}

func convertToJSON(localization: Localization, to filePath: String) {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    if let data = try? encoder.encode(localization) {
        try? data.write(to: URL(fileURLWithPath: filePath))
    }
}

// Example usage:
//if let localization = parseJSON(from: "/path/to/Localizable.xcstrings") {
//    convertToCSV(localization: localization, to: "/path/to/Localizable.csv")
//}
//
//if let localization = parseCSV(from: "/path/to/Localizable.csv") {
//    convertToJSON(localization: localization, to: "/path/to/Localizable.xcstrings")
//}

extension Collection {
    // Returns the element at the specified index if it is within bounds, otherwise nil.
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

if CommandLine.arguments.count >= 3 {
    var args = CommandLine.arguments
    var langs: [String]?
    if let idx = args.firstIndex(of: "-l"), let languages = args[safe: idx+1] {
        langs = languages.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines)}
        args.removeSubrange(idx...idx+1)
    }
    let source = args[1]
    let dest = args[2]
    if let localization = parseJSON(from: source) {
        convertToCSV(localization: localization, to: dest, languages: langs)
    }
}
