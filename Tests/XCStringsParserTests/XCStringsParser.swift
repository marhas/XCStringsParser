//
//  XCStringsParser.swift
//
//  Created by Marcel Hasselaar on 2024-11-23.
//

import Foundation
import Testing
import XCStringsParser

struct Test {

    @Test func verifyCorrectXCStringsParsing() async throws {
        let parser = XCStringsParser()
        let localization = try #require(parser.parseJSON(from: Bundle.module.path(forResource: "Localizable", ofType: "xcstrings")!))
        #expect(localization.strings.count == 3)
        #expect(localization.strings.first?.value.localizations.count == 5)
        let connectedScoreboardLocalizations = try #require(localization.strings["Connected scoreboards"]?.localizations)
        #expect(connectedScoreboardLocalizations["de"]?.stringUnit.value == "Verbundene Anzeigetafeln")
        #expect(connectedScoreboardLocalizations["fr"]?.stringUnit.value == "Tableaux de scores connectés")
        #expect(localization.strings["Connected scoreboards"]?.comment == "Connected scoreboards")
        #expect(localization.sourceLanguage == "en")
        #expect(localization.version == "1.0")
    }

    // When localizations are merged, any updated translations in the updated file should be merged into the source file, but comments are considered read only and will be ignored in the merge (i.e. the original xcstrings files comments will prevail)
    @Test func mergeLocalizations() async throws {
        let parser = XCStringsParser()
        let sourceLocalization = try #require(parser.parseJSON(from: Bundle.module.path(forResource: "Localizable", ofType: "xcstrings")!))
        let updatedLocalization = try #require(parser.parseJSON(from: Bundle.module.path(forResource: "Localizable_en_fr", ofType: "xcstrings")!))

        let merged = sourceLocalization.merge(updatedLocalization)
        #expect(updatedLocalization.strings["Decrease home team score"]?.localizations.count == 2)
        #expect(sourceLocalization.strings["Decrease home team score"]?.localizations["en"]?.stringUnit.value == "Decrease home team score")
        #expect(merged.strings["Decrease home team score"]?.localizations["en"]?.stringUnit.value == "EN Decrease home team score")
        #expect(sourceLocalization.strings["Decrease home team score"]?.localizations["fr"]?.stringUnit.value == "Diminuer le score de l'équipe à domicile")
        #expect(merged.strings["Decrease home team score"]?.localizations["fr"]?.stringUnit.value == "FR Diminuer le score de l'équipe à domicile")
        #expect(merged.strings["Decrease home team score"]?.localizations["sv"]?.stringUnit.value == "Minska hemmalagets poäng")

        #expect(sourceLocalization.strings["Decrease home team score"]?.comment == "Shortcut action")
        #expect(updatedLocalization.strings["Decrease home team score"]?.comment == "Shortcut action (comments are not expected to be changed in updated xcstrings files)")
        #expect(merged.strings["Decrease home team score"]?.comment == "Shortcut action", "Expected original comment to be preserved")

        // String that only exists in the updated translation file should be ignored
        #expect(sourceLocalization.strings["flic.longTapAction"] == nil)
        #expect(updatedLocalization.strings["flic.longTapAction"]?.localizations.count == 4)
        #expect(merged.strings["flic.longTapAction"] == nil)

        // String that only exists in the original translation file
        #expect(sourceLocalization.strings["Connected scoreboards"]?.localizations.count == 5)
        #expect(merged.strings["Connected scoreboards"]?.localizations["de"]?.stringUnit.value == "Verbundene Anzeigetafeln")
        #expect(merged.strings["Connected scoreboards"]?.localizations["fr"]?.stringUnit.value == "Tableaux de scores connectés")
    }

    @Test func mergeSelectedLocalizations() async throws {
        let parser = XCStringsParser()
        let sourceLocalization = try #require(parser.parseJSON(from: Bundle.module.path(forResource: "Localizable", ofType: "xcstrings")!))
        let updatedLocalization = try #require(parser.parseJSON(from: Bundle.module.path(forResource: "Localizable_update", ofType: "xcstrings")!))

        let merged = sourceLocalization.merge(updatedLocalization, languages: ["en", "fr", "sv"])
        #expect(updatedLocalization.strings["Deuce"]?.localizations.count == 5)
        #expect(sourceLocalization.strings["Deuce"]?.localizations["en"]?.stringUnit.value == "Deuce")
        #expect(merged.strings["Deuce"]?.localizations["en"]?.stringUnit.value == "EN Deuce")
        #expect(sourceLocalization.strings["Deuce"]?.localizations["sv"]?.stringUnit.value == "Lika")
        #expect(merged.strings["Deuce"]?.localizations["sv"]?.stringUnit.value == "SV Lika")
        #expect(sourceLocalization.strings["Deuce"]?.localizations["es"]?.stringUnit.value == "Deuce")
        #expect(merged.strings["Deuce"]?.localizations["es"]?.stringUnit.value == "Deuce")  // Excluded in language selection
        #expect(sourceLocalization.strings["Deuce"]?.localizations["de"]?.stringUnit.value == "Einstand")
        #expect(merged.strings["Deuce"]?.localizations["de"]?.stringUnit.value == "Einstand")  // Excluded in language selection
    }

    @Test func convertToCSVAndBack() throws {
        let parser = XCStringsParser()
        let sourceLocalization = try #require(parser.parseJSON(from: Bundle.module.path(forResource: "Localizable", ofType: "xcstrings")!))
        let tempDir = FileManager.default.temporaryDirectory
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let tempFile = tempDir.appendingPathComponent(UUID().uuidString).appendingPathExtension("csv").path()
        parser.convertToCSV(localization: sourceLocalization, to: tempFile, delimiter: ";")
        let importedLocalization = try #require(try parser.parseCSV(from: tempFile, delimiter: ";"))

        for stringKey in importedLocalization.strings.keys {
            #expect(sourceLocalization.strings[stringKey]?.localizations == importedLocalization.strings[stringKey]?.localizations)
        }
        #expect(sourceLocalization.version == importedLocalization.version)
        #expect(sourceLocalization.sourceLanguage == importedLocalization.sourceLanguage)
    }
}
