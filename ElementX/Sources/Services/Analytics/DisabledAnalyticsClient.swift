//
// Copyright 2026 Che Tianshi
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import AnalyticsEvents

/// Keeps the upstream analytics surface inert in the managed family build.
final class DisabledAnalyticsClient: AnalyticsClientProtocol {
    let isRunning = false
    
    func start(analyticsConfiguration: AnalyticsConfiguration) { }
    func reset() { }
    func stop() { }
    func capture(_ event: AnalyticsEventProtocol) { }
    func screen(_ event: AnalyticsScreenProtocol) { }
    func updateUserProperties(_ event: AnalyticsEvent.UserProperties) { }
}
