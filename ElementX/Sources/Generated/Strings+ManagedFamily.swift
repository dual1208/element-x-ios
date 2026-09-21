// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

import Foundation

// swiftlint:disable superfluous_disable_command file_length implicit_return

// MARK: - Strings

// swiftlint:disable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:disable nesting type_body_length type_name vertical_whitespace_opening_braces
internal nonisolated enum ManagedFamilyL10n {
  /// Incoming call alerts
  internal static var managedFamilyCallNotifications: String { return ManagedFamilyL10n.tr("ManagedFamily", "managed_family_call_notifications") }
  /// You can sign back in later with the same account.
  internal static var managedFamilyLogoutMessage: String { return ManagedFamilyL10n.tr("ManagedFamily", "managed_family_logout_message") }
  /// Sign out
  internal static var managedFamilyLogoutSubmit: String { return ManagedFamilyL10n.tr("ManagedFamily", "managed_family_logout_submit") }
  /// Sign out
  internal static var managedFamilyLogoutTitle: String { return ManagedFamilyL10n.tr("ManagedFamily", "managed_family_logout_title") }
  /// Message alerts
  internal static var managedFamilyMessageNotifications: String { return ManagedFamilyL10n.tr("ManagedFamily", "managed_family_message_notifications") }
  /// Continue
  internal static var managedFamilyOnboardingContinue: String { return ManagedFamilyL10n.tr("ManagedFamily", "managed_family_onboarding_continue") }
  /// Sign in with the account your family gave you. Your family group opens automatically.
  internal static var managedFamilyOnboardingMessage: String { return ManagedFamilyL10n.tr("ManagedFamily", "managed_family_onboarding_message") }
  /// Family chat
  internal static var managedFamilyOnboardingTitle: String { return ManagedFamilyL10n.tr("ManagedFamily", "managed_family_onboarding_title") }
  /// Connecting to the family group
  internal static var managedFamilySetupNeedsHelp: String { return ManagedFamilyL10n.tr("ManagedFamily", "managed_family_setup_needs_help") }
  /// If it does not open, check the account in Settings or ask the family member who installed the app.
  internal static var managedFamilySetupNeedsHelpMessage: String { return ManagedFamilyL10n.tr("ManagedFamily", "managed_family_setup_needs_help_message") }
}
// swiftlint:enable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:enable nesting type_body_length type_name vertical_whitespace_opening_braces

// MARK: - Implementation Details

nonisolated extension ManagedFamilyL10n {
  static func tr(_ table: String, _ key: String, _ args: CVarArg...) -> String {
    // Use preferredLocalizations to get a language that is in the bundle and the user's preferred list of languages.
    let languages = Bundle.overrideLocalizations ?? Bundle.app.preferredLocalizations

    for language in languages {
      if let translation = trIn(language, table, key, args) {
        return translation
      }
    }
    return Bundle.app.developmentLocalization.flatMap { trIn($0, table, key, args) } ?? key
  }

  private static func trIn(_ language: String, _ table: String, _ key: String, _ args: CVarArg...) -> String? {
    guard let bundle = Bundle.lprojBundle(for: language) else { return nil }
    let format = NSLocalizedString(key, tableName: table, bundle: bundle, comment: "")
    let translation = String(format: format, locale: Locale(identifier: language), arguments: args)
    guard translation != key, 
          translation != "\(key) \(key)" // Handle double pseudo for tests
      else { 
        return nil 
      }
    return translation
  }
}

// swiftlint:enable all
