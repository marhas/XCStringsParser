//
//  main.swift
//  XCStringsParser
//
//  Created by Marcel Hasselaar on 2024-11-12.
//

import Foundation
import OrderedCollections
import SwiftCSV


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

func parseCSV2(from filePath: String, sourceLanguage: String = "en", keyColumn: String = "key", separator: any RegexComponent = /,/, languages: [String]? = nil) throws -> Localization? {
    let csv = try CSV<Named>(url: URL(string: "file://\(filePath)")!, encoding: .utf8, loadColumns: true)
    let columns = csv.rows
        for x in columns {
            print("\(x)\n\n")
        }

    return nil
}

func parseCSV(from filePath: String, sourceLanguage: String = "en", keyColumn: String = "key", separator: any RegexComponent = /,/, languages: [String]? = nil) throws -> Localization? {
    let csv = try CSV<Named>(url: URL(string: "file://\(filePath)")!, encoding: .utf8, loadColumns: true)
    guard csv.header.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces).caseInsensitiveCompare(keyColumn) == .orderedSame }) != nil else {
        print("A key column named \(keyColumn) was not found.")
        exit(1)
    }

    var strings: [String: LocalizedString] = [:]

    for row in csv.rows {
        var localizations = [String: LocalizationValue]()
        guard let key = row["Key"] else {
            print("No Key found in row: \(row)")
            continue
        }
        for lang in row.keys {
            if lang == "Key" { continue }
            if let languages, !languages.contains(lang) { continue }

            let localizationValue = LocalizationValue(stringUnit: StringUnit(state: "translated", value: String(row[lang] ?? "")))
            localizations[lang] = localizationValue
        }

        strings[key] = LocalizedString(comment: nil, extractionState: "manual", localizations: localizations)
    }
    return Localization(sourceLanguage: sourceLanguage, strings: strings)
}

func parseCSV3(from filePath: String, sourceLanguage: String = "en", keyColumn: String = "key", separator: any RegexComponent = /,/, languages: [String]? = nil) -> Localization? {
    guard let csvString = try? String(contentsOf: URL(fileURLWithPath: filePath), encoding: .utf8) else { return nil }
    var lines = csvString.components(separatedBy: "\n")
    let header = lines.removeFirst()
    let headerColumns = Array(header.split(separator: separator))
    guard let keyColumnIndex = headerColumns.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces).caseInsensitiveCompare(keyColumn) == .orderedSame }) else {
        print("A key column was not found.")
        exit(1)
    }
    var langColumnIndexes = [String:Int]()
    for index in 0..<headerColumns.count {
        if index == keyColumnIndex { continue }
        let lang = String(headerColumns[index].trimmingCharacters(in: .whitespacesAndNewlines))
        if let languages, !languages.contains(lang) { continue }  // If we're given a list of languages, only read the languages in the list and ignore others
        langColumnIndexes[String(lang)] = index
    }

    guard langColumnIndexes.count >= 1 else {
        print("No matching language columns found.")
        return nil
    }

    var strings: [String: LocalizedString] = [:]

    for (lineNo, line) in lines.enumerated() {
        let lineColumns = line.split(separator: separator)

        guard let key = lineColumns[safe: keyColumnIndex] else {
            print("Warning: key not found on line \(lineNo), skipping line:\n \(line).")
            continue
        }

        var localizations = [String: LocalizationValue]()
        for index in 0..<lineColumns.count {
            if index == keyColumnIndex { continue }
            if let lang = lineColumns[safe: index] {
                let localizationValue = LocalizationValue(stringUnit: StringUnit(state: "translated", value: String(lineColumns[safe: index] ?? "")))
                localizations[String(lang)] = localizationValue
            }
        }

        strings[String(key)] = LocalizedString(comment: nil, extractionState: "manual", localizations: localizations)
    }

    return Localization(sourceLanguage: sourceLanguage, strings: strings)
}

func backupFile(at path: String) throws {
    let fm = FileManager()
    let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd-HH.mm.ss"
        return df
    }()
    if fm.fileExists(atPath: path) {
        let backupFileName = "\(path).org-\(dateFormatter.string(from: Date()))"
        try fm.copyItem(atPath: path, toPath: backupFileName)
    }
}

extension Localization {
    func merge(_ updatedLocalization: Localization, languages: [String]? = nil) -> Localization {
        var existingStrings = self.strings

        for (key, localizedString) in updatedLocalization.strings {
            var trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
            if let existingLocalizedString = existingStrings[trimmedKey] {
                var mergedLocalizations = existingLocalizedString.localizations

                for (language, localizationValue) in localizedString.localizations {
                    if let languages, !languages.contains(language) { continue }  // If we're given a list of languages, only merge the languages in the list and ignore others
                    mergedLocalizations[language] = localizationValue
                }

                existingStrings[trimmedKey] = LocalizedString(comment: existingLocalizedString.comment ?? localizedString.comment,
                                                     extractionState: existingLocalizedString.extractionState,
                                                     localizations: mergedLocalizations)
            } else {
                print("Warning: key '\(trimmedKey)' not found in existing localization.")
            }
        }
        return Localization(sourceLanguage: self.sourceLanguage, strings: existingStrings)
    }

    func writeJson(to filePath: String) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(self) {
            print("Writing \(filePath).")
            try? data.write(to: URL(fileURLWithPath: filePath))
        }
    }
}

extension Collection {
    // Returns the element at the specified index if it is within bounds, otherwise nil.
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

extension String {
    var isXCStrings: Bool {
        return hasSuffix(".xcstrings")
    }

    var isCSV: Bool {
        return hasSuffix(".csv")
    }
}

if CommandLine.arguments.count >= 3 {
    var args = CommandLine.arguments
    var langs: [String]?
    var separatorRegex: any RegexComponent = /,/

    if let idx = args.firstIndex(of: "-l"), let languages = args[safe: idx+1] {
        langs = languages.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines)}
        args.removeSubrange(idx...idx+1)
    }
    if let idx = args.firstIndex(of: "-s"), let separatorRegexString = args[safe: idx+1] {
        separatorRegex = try Regex(separatorRegexString)
        args.removeSubrange(idx...idx+1)
    }
    let source = args[1]
    let dest = args[2]

    guard FileManager.default.fileExists(atPath: source) else {
        print("\(source) not found")
        exit(1)
    }

    if source.isXCStrings {
        if let localization = parseJSON(from: source) {
            convertToCSV(localization: localization, to: dest, languages: langs)
        }
    } else if source.isCSV, dest.isXCStrings {
        if let updatedLocalization = try parseCSV(from: source, separator: separatorRegex, languages: langs) {
            if FileManager.default.fileExists(atPath: dest) {
                guard let existingLocalization = parseJSON(from: dest) else {
                    print("Cannot read \(dest)")
                    exit(1)
                }
                let mergedLocalization = existingLocalization.merge(updatedLocalization, languages: langs)
                try backupFile(at: dest)
                try mergedLocalization.writeJson(to: dest)
            } else {
                try updatedLocalization.writeJson(to: dest)
            }
        }
    } else {
        usage()
        exit(1)
    }
}

func usage() {
    print("""
This program can export xcstring files to csv files and import csv files back into a new or existing xcstrings file.

Exporting:
$0 <source xcstrings file> <dest csv file> [options]

Importing:
$0 <source csv file> <dest xcstrings file> [options]

Options:
-l comma separated list of languages to export
-s delimiter to use for csv

""")
}
