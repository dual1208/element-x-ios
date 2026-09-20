//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

@testable import ElementX
import Foundation
import Testing

@Suite(.serialized)
final class LocalizationTests {
    deinit {
        Bundle.overrideLocalizations = nil
    }
    
    /// Test ElementL10n considers app language changes
    @Test
    func appLanguage() {
        // set app language to English
        Bundle.overrideLocalizations = ["en"]
        
        #expect(L10n.testLanguageIdentifier == "en")
        
        // set app language to Italian
        Bundle.overrideLocalizations = ["it"]
        
        #expect(L10n.testLanguageIdentifier == "it")
    }
    
    /// Test fallback language for a language not supported at all
    @Test
    func fallbackOnNotSupportedLanguage() {
        //  set app language to something Element don't support at all (chose non existing identifier)
        Bundle.overrideLocalizations = ["xx"]
        
        #expect(L10n.testLanguageIdentifier == "en")
    }
    
    /// Test fallback language for a language supported but poorly translated
    @Test
    func fallbackOnNotTranslatedKey() {
        //  set app language to something Element supports but use a key that is not translated (we have a key that should never be translated)
        Bundle.overrideLocalizations = ["it"]
        
        #expect(L10n.testLanguageIdentifier == "it")
        #expect(L10n.testUntranslatedDefaultLanguageIdentifier == "en")
    }
    
    /// Test plurals that ElementL10n considers app language changes
    @Test
    func plurals() {
        //  set app language to English
        Bundle.overrideLocalizations = ["en"]
        
        #expect(L10n.commonMemberCount(1) == "1 Member")
        #expect(L10n.commonMemberCount(2) == "2 Members")
        
        //  set app language to Italian
        Bundle.overrideLocalizations = ["it"]
        
        #expect(L10n.commonMemberCount(1) == "1 Membro")
        #expect(L10n.commonMemberCount(2) == "2 Membri")
    }
    
    /// Test plurals fallback language for a language not supported at all
    @Test
    func pluralsFallbackOnNotSupportedLanguage() {
        //  set app language to something Element don't support at all ("invalid identifier")
        Bundle.overrideLocalizations = ["xx"]
        
        #expect(L10n.commonMemberCount(1) == "1 Member")
        #expect(L10n.commonMemberCount(2) == "2 Members")
    }
    
    /// Test untranslated strings
    @Test
    func untranslated() {
        #expect(UntranslatedL10n.untranslated == "Untranslated")
        #expect(UntranslatedL10n.untranslatedPlural(1) == "One untranslated item")
        #expect(UntranslatedL10n.untranslatedPlural(5) == "5 untranslated items")
    }
    
    @Test
    func managedFamily() {
        Bundle.overrideLocalizations = ["en"]
        #expect(ManagedFamilyL10n.managedFamilyOnboardingTitle == "Family chat")
        #expect(ManagedFamilyL10n.managedFamilyOnboardingMessage == "Sign in with the account your family gave you. For first-time setup, ask the family member who installed the app to help.")
        #expect(ManagedFamilyL10n.managedFamilyOnboardingContinue == "Continue")
        #expect(ManagedFamilyL10n.managedFamilySetupNeedsHelp == "Family chat needs help")
        #expect(ManagedFamilyL10n.managedFamilySetupNeedsHelpMessage == "Open Settings to finish account setup, or ask the family member who installed the app to help.")
        
        Bundle.overrideLocalizations = ["zh-Hans"]
        #expect(ManagedFamilyL10n.managedFamilyOnboardingTitle == "家人聊天")
        #expect(ManagedFamilyL10n.managedFamilyOnboardingMessage == "使用家人给你的账号登录。第一次使用时，请让帮你安装的家人陪你完成设置。")
        #expect(ManagedFamilyL10n.managedFamilyOnboardingContinue == "继续")
        #expect(ManagedFamilyL10n.managedFamilySetupNeedsHelp == "家人聊天需要帮助")
        #expect(ManagedFamilyL10n.managedFamilySetupNeedsHelpMessage == "请打开“设置”完成账号设置，或请帮你安装这个应用的家人来处理。")
        
        Bundle.overrideLocalizations = ["xx"]
        #expect(ManagedFamilyL10n.managedFamilyOnboardingTitle == "Family chat")
        #expect(ManagedFamilyL10n.managedFamilyOnboardingContinue == "Continue")
    }
}
