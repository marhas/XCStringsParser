//
//  XCStringsParser
//
//  Exports an XCStrings file to CVS which can be sent out for translation
//  Can then import it back again, merging the translations with your current xcstrings file.
//
//  Created by Marcel Hasselaar on 2024-11-12.
//

import Foundation
import OrderedCollections
import SwiftCSV


let defaultDelimiter: Character = ";"

public struct Localization: Codable, Equatable {
    public let sourceLanguage: String
    public let strings: [String: LocalizedString]
    public let version: String
}

public struct LocalizedString: Codable, Equatable {
    public let comment: String?
    public let extractionState: String
    public var localizations: [String: LocalizationValue]
}

public struct LocalizationValue: Codable, Equatable {
    public let stringUnit: StringUnit
}

public struct StringUnit: Codable, Equatable {
    public let state: String
    public let value: String
}


public struct XCStringsParser {
    public init() {}
    
    public func parseJSON(from filePath: String) -> Localization? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else { return nil }
        let decoder = JSONDecoder()
        return try? decoder.decode(Localization.self, from: data)
    }

    public func convertToCSV(localization: Localization, to filePath: String, delimiter: String, languages: [String]? = nil) {
        let localizedLanguages = Set(localization.strings.first!.value.localizations.keys)
        let filteredLocalizedLanguages = languages.map { OrderedSet($0) }.map { localizedLanguages.intersection($0) } ?? localizedLanguages

        var csvString = "Key" + delimiter + filteredLocalizedLanguages.joined(separator: delimiter) + delimiter + "Comment\n"
        for (key, localizedString) in localization.strings.sorted(by: { $0.key < $1.key }) {
            let comment = localizedString.comment ?? ""
            var line = "\(key)\(delimiter)"
            for lang in filteredLocalizedLanguages {
                line += quote("\(localizedString.localizations[lang]?.stringUnit.value ?? "")") + delimiter
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

    // Strings that contain newlines needs to be quoted in order to be correctly imported into most programs.
    // Also, if a string contains the " character, it needs to be "escaped" by replacing it with two " characters, i.e. "word" -> ""word""
    private func quote(_ string: String) -> String {
        guard string.contains(/[\"\n]/) else { return string }
        return
        "\"" + string
            .replacingOccurrences(of: "\"", with: "\"\"")
        + "\""
    }

    public func parseCSV(from filePath: String, sourceLanguage: String = "en", keyColumn: String = "Key", commentColumn: String = "comment", delimiter: String, languages: [String]? = nil) throws -> Localization? {
        let delimiter = delimiter.first ?? defaultDelimiter
        let csv = try CSV<Named>(url: URL(string: "file://\(filePath)")!, delimiter: .character(delimiter), encoding: .utf8, loadColumns: true)
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
            for col in row.keys {
                // All columns are expected to be languages except for the key and comment columns
                if col.caseInsensitiveCompare(keyColumn) == .orderedSame || col.caseInsensitiveCompare(commentColumn) == .orderedSame { continue }
                if let languages, !languages.contains(col) { continue }

                let localizationValue = LocalizationValue(stringUnit: StringUnit(state: "translated", value: String(row[col] ?? "")))
                localizations[col] = localizationValue
            }

            strings[key] = LocalizedString(comment: row["comment"], extractionState: "manual", localizations: localizations)
        }
        return Localization(sourceLanguage: sourceLanguage, strings: strings, version: "1.0")
    }

    public func backupFile(at path: String) throws {
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
}

public extension Localization {
    func merge(_ updatedLocalization: Localization, languages: [String]? = nil) -> Localization {
        var existingStrings = self.strings

        for (key, localizedString) in updatedLocalization.strings {
            let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
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
        return Localization(sourceLanguage: self.sourceLanguage, strings: existingStrings, version: self.version)
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

guard CommandLine.arguments.count >= 3 else {
    usage()
    exit(1)
}

var args = CommandLine.arguments
var langs: [String]?
var csvDelimiter = defaultDelimiter


if let idx = args.firstIndex(of: "-l"), let languages = args[safe: idx+1] {
    langs = languages.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines)}
    args.removeSubrange(idx...idx+1)
}
if let idx = args.firstIndex(of: "-d"), let delimiter = args[safe: idx+1], let delimiterChar = delimiter.first {
    csvDelimiter = delimiterChar
    args.removeSubrange(idx...idx+1)
}
let source = args[1]
let dest = args[2]

guard FileManager.default.fileExists(atPath: source) else {
    print("\(source) not found")
    exit(1)
}

let parser = XCStringsParser()

if source.isXCStrings {
    if let localization = parser.parseJSON(from: source) {
        parser.convertToCSV(localization: localization, to: dest, delimiter: String(csvDelimiter), languages: langs)
    }
} else if source.isCSV, dest.isXCStrings {
    if let updatedLocalization = try parser.parseCSV(from: source, delimiter: String(csvDelimiter), languages: langs) {
        if FileManager.default.fileExists(atPath: dest) {
            guard let existingLocalization = parser.parseJSON(from: dest) else {
                print("Cannot read \(dest)")
                exit(1)
            }
            let mergedLocalization = existingLocalization.merge(updatedLocalization, languages: langs)
            try parser.backupFile(at: dest)
            try mergedLocalization.writeJson(to: dest)
        } else {
            try updatedLocalization.writeJson(to: dest)
        }
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
-d delimiter to use for csv

""")
}
