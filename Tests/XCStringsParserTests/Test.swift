//
//  Test.swift
//  XCStringsParser
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
        #expect(localization.strings.count == 2)
        #expect(localization.strings.first?.value.localizations.count == 5)
        let connectedScoreboardLocalizations = try #require(localization.strings["Connected scoreboards"]?.localizations)
        #expect(connectedScoreboardLocalizations["de"]?.stringUnit.value == "Verbundene Anzeigetafeln")
        #expect(connectedScoreboardLocalizations["fr"]?.stringUnit.value == "Tableaux de scores connectés")
        #expect(localization.strings["Connected scoreboards"]?.comment == "Connected scoreboards")
        #expect(localization.sourceLanguage == "en")
        #expect(localization.version == "1.0")
    }

    // When localizations are merged, the any updated translations in the second file should be merged into the new file, but comments are considered read only and will be ignored in the merge (i.e. the original xcstrings files comments will prevail)
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
}
