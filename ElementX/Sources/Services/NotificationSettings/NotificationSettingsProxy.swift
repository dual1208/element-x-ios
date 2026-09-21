//
// Copyright 2025 Element Creations Ltd.
// Copyright 2023-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import Foundation
import MatrixRustSDK

private final class WeakNotificationSettingsProxy: NotificationSettingsDelegate {
    @MainActor private weak var proxy: NotificationSettingsProxy?
    
    @MainActor init(proxy: NotificationSettingsProxy) {
        self.proxy = proxy
    }
    
    // MARK: - NotificationSettingsDelegate
    
    /// Called by the SDK from arbitrary threads, hop to the main actor where the proxy lives.
    func settingsDidChange() {
        Task { @MainActor in
            self.proxy?.settingsDidChange()
        }
    }
}

final class NotificationSettingsProxy: NotificationSettingsProxyProtocol {
    private(set) var notificationSettings: MatrixRustSDK.NotificationSettingsProtocol
    
    let callbacks = PassthroughSubject<NotificationSettingsProxyCallback, Never>()
    
    init(notificationSettings: MatrixRustSDK.NotificationSettingsProtocol) {
        self.notificationSettings = notificationSettings
        notificationSettings.setDelegate(delegate: WeakNotificationSettingsProxy(proxy: self))
    }
    
    func getNotificationSettings(roomId: String, isEncrypted: Bool, isOneToOne: Bool) async throws -> RoomNotificationSettingsProxyProtocol {
        let roomMotificationSettings = try await notificationSettings.getRoomNotificationSettings(roomId: roomId, isEncrypted: isEncrypted, isOneToOne: isOneToOne)
        return RoomNotificationSettingsProxy(roomNotificationSettings: roomMotificationSettings)
    }
    
    func setNotificationMode(roomId: String, mode: RoomNotificationModeProxy) async throws {
        try await notificationSettings.setRoomNotificationMode(roomId: roomId, mode: mode.roomNotificationMode)
        await updatedSettings()
    }
    
    func getUserDefinedRoomNotificationMode(roomId: String) async throws -> RoomNotificationModeProxy? {
        let roomNotificationMode = try await notificationSettings.getUserDefinedRoomNotificationMode(roomId: roomId)
        return roomNotificationMode.flatMap { RoomNotificationModeProxy.from(roomNotificationMode: $0) }
    }
    
    func getDefaultRoomNotificationMode(isEncrypted: Bool, isOneToOne: Bool) async -> RoomNotificationModeProxy {
        let roomNotificationMode = await notificationSettings.getDefaultRoomNotificationMode(isEncrypted: isEncrypted, isOneToOne: isOneToOne)
        return RoomNotificationModeProxy.from(roomNotificationMode: roomNotificationMode)
    }
    
    func setDefaultRoomNotificationMode(isEncrypted: Bool, isOneToOne: Bool, mode: RoomNotificationModeProxy) async throws {
        do {
            try await notificationSettings.setDefaultRoomNotificationMode(isEncrypted: isEncrypted, isOneToOne: isOneToOne, mode: mode.roomNotificationMode)
        } catch NotificationSettingsError.RuleNotFound(let ruleId) {
            // `setDefaultRoomNotificationMode` updates multiple rules including unstable rules (e.g. the polls push rules defined in the MSC3930)
            // since production home servers may not have these rules yet, we drop the RuleNotFound error
            MXLog.warning("Unable to find the rule: \(ruleId)")
            return
        }
        
        await updatedSettings()
    }
    
    func restoreDefaultNotificationMode(roomId: String) async throws {
        try await notificationSettings.restoreDefaultRoomNotificationMode(roomId: roomId)
        await updatedSettings()
    }
    
    func unmuteRoom(roomId: String, isEncrypted: Bool, isOneToOne: Bool) async throws {
        try await notificationSettings.unmuteRoom(roomId: roomId, isEncrypted: isEncrypted, isOneToOne: isOneToOne)
        await updatedSettings()
    }
    
    func isRoomMentionEnabled() async throws -> Bool {
        try await notificationSettings.isRoomMentionEnabled()
    }
    
    func setRoomMentionEnabled(enabled: Bool) async throws {
        try await notificationSettings.setRoomMentionEnabled(enabled: enabled)
        await updatedSettings()
    }
    
    func isCallEnabled() async throws -> Bool {
        try await notificationSettings.isCallEnabled()
    }
    
    func setCallEnabled(enabled: Bool) async throws {
        try await notificationSettings.setCallEnabled(enabled: enabled)
        await updatedSettings()
    }
    
    func setManagedFamilyMessageNotifications(roomID: String, enabled: Bool) async throws {
        // A room-level mute rule would outrank MatrixRTC's call rules and silence calls too.
        // Match only message events so the two family switches remain independent.
        try await setManagedFamilyPushRule(id: "io.familychat.message_notifications",
                                           roomID: roomID,
                                           eventType: "m.room.message",
                                           enabled: enabled)
    }
    
    func setManagedFamilyCallNotifications(roomID: String, enabled: Bool) async throws {
        try await notificationSettings.setCallEnabled(enabled: enabled)
        try await setManagedFamilyPushRule(id: "io.familychat.call-alerts.stable",
                                           roomID: roomID,
                                           eventType: "m.rtc.notification",
                                           enabled: enabled)
        try await setManagedFamilyPushRule(id: "io.familychat.call-alerts.unstable",
                                           roomID: roomID,
                                           eventType: "org.matrix.msc4075.rtc.notification",
                                           enabled: enabled)
        await updatedSettings()
    }
    
    func managedFamilyMessageNotificationsEnabled() async throws -> Bool? {
        let rules = try await managedFamilyOverrideRules()
        return managedFamilyRuleEnabled(id: "io.familychat.message_notifications", rules: rules)
    }
    
    func managedFamilyCallNotificationsEnabled() async throws -> Bool? {
        let rules = try await managedFamilyOverrideRules()
        let values = ["io.familychat.call-alerts.stable", "io.familychat.call-alerts.unstable"]
            .compactMap { managedFamilyRuleEnabled(id: $0, rules: rules) }
        return values.isEmpty ? nil : values.allSatisfy { $0 }
    }
    
    func isInviteForMeEnabled() async throws -> Bool {
        try await notificationSettings.isInviteForMeEnabled()
    }
    
    func setInviteForMeEnabled(enabled: Bool) async throws {
        try await notificationSettings.setInviteForMeEnabled(enabled: enabled)
        await updatedSettings()
    }
    
    func getRoomsWithUserDefinedRules() async throws -> [String] {
        await notificationSettings.getRoomsWithUserDefinedRules(enabled: true)
    }
    
    func canPushEncryptedEventsToDevice() async -> Bool {
        await notificationSettings.canPushEncryptedEventToDevice()
    }
    
    // MARK: - Private
    
    func updatedSettings() async {
        // The timeout avoids having to wait indefinitely. This can happen when setting a mode that is already the current mode,
        // as in this case no API call is made by the RustSDK and the push rules are therefore not updated.
        var iterator = callbacks
            .timeout(.seconds(2.0), scheduler: DispatchQueue.main, options: nil, customError: nil)
            .values
            .makeAsyncIterator()
        
        while let callback = await iterator.next(isolation: #isolation) {
            if callback == .settingsDidChange {
                break
            }
        }
    }
    
    func settingsDidChange() {
        callbacks.send(.settingsDidChange)
    }
    
    private func setManagedFamilyPushRule(id: String,
                                          roomID: String,
                                          eventType: String,
                                          enabled: Bool) async throws {
        let actions: [Action] = enabled ? [.notify] : []
        try await notificationSettings.setCustomPushRule(ruleId: id,
                                                         ruleKind: .override,
                                                         actions: actions,
                                                         conditions: [
                                                             .eventMatch(key: "room_id", pattern: roomID),
                                                             .eventMatch(key: "type", pattern: eventType)
                                                         ])
    }
    
    private func managedFamilyOverrideRules() async throws -> [[String: Any]] {
        guard let rawRules = try await notificationSettings.getRawPushRules(),
              let data = rawRules.data(using: .utf8),
              let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let global = root["global"] as? [String: Any] else {
            return []
        }
        return global["override"] as? [[String: Any]] ?? []
    }
    
    private func managedFamilyRuleEnabled(id: String, rules: [[String: Any]]) -> Bool? {
        guard let rule = rules.first(where: { $0["rule_id"] as? String == id }) else { return nil }
        guard rule["enabled"] as? Bool != false,
              let actions = rule["actions"] as? [Any] else {
            return false
        }
        return actions.contains { $0 as? String == "notify" }
    }
}
