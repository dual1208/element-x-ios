//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import SwiftUI

enum AuthenticationStartScreenViewModelAction: Equatable {
    case loginWithQR
    case login
    case register
    
    case loginDirectlyWithOAuth(data: OAuthAuthorizationDataProxy, window: UIWindow)
    case loginDirectlyWithPassword(loginHint: String?)
    
    case reportProblem
    case developerOptions
}

struct AuthenticationStartScreenViewState: BindableState {
    /// The presentation anchor used for OAuth authentication.
    var window: UIWindow?
    
    let serverName: String?
    let showCreateAccountButton: Bool
    let showQRCodeLoginButton: Bool
    let isManagedFamilyMode: Bool
    
    enum ClassicAppMode { case welcomeBack(ClassicAppAccount), otherOptions(ClassicAppAccount) }
    var classicAppMode: ClassicAppMode?
    
    let hideBrandChrome: Bool
    
    var bindings = AuthenticationStartScreenViewStateBindings()
    
    var title: String {
        isManagedFamilyMode ? ManagedFamilyL10n.managedFamilyOnboardingTitle : L10n.screenOnboardingWelcomeTitle
    }
    
    var message: String {
        isManagedFamilyMode ? ManagedFamilyL10n.managedFamilyOnboardingMessage : L10n.screenOnboardingWelcomeMessage(InfoPlistReader.main.productionAppName)
    }
    
    var loginButtonTitle: String {
        if isManagedFamilyMode {
            ManagedFamilyL10n.managedFamilyOnboardingContinue
        } else if let serverName {
            L10n.screenOnboardingSignInTo(serverName)
        } else if showQRCodeLoginButton {
            L10n.screenOnboardingSignInManually
        } else {
            L10n.actionContinue
        }
    }
}

struct AuthenticationStartScreenViewStateBindings {
    var alertInfo: AlertInfo<AuthenticationStartScreenAlertType>?
    var showClassicAppBackupInstructions = false
}

enum AuthenticationStartScreenAlertType {
    case genericError
}

enum AuthenticationStartScreenViewAction {
    /// Updates the window used as the OAuth presentation anchor.
    case updateWindow(UIWindow)
    case developerOptions
    case reportProblem
    
    case loginWithQR
    case login
    case register
    
    case continueWithClassic(ClassicAppAccount)
    case otherOptions(ClassicAppAccount)
    case closeOtherOptions(ClassicAppAccount)
    case openClassicApp
}
