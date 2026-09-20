[![Element iOS Matrix room #element-x-ios:matrix.org](https://img.shields.io/matrix/element-x-ios:matrix.org.svg?label=%23element-x-ios:matrix.org&logo=matrix&server_fqdn=matrix.org)](https://matrix.to/#/#element-x-ios:matrix.org)
![GitHub](https://img.shields.io/github/license/element-hq/element-x-ios)

![Build Status](https://img.shields.io/github/actions/workflow/status/element-hq/element-x-ios/unit-tests.yml)
![GitHub release (latest by date)](https://img.shields.io/github/v/release/element-hq/element-x-ios)

[![codecov](https://codecov.io/gh/element-hq/element-x-ios/branch/develop/graph/badge.svg?token=AVIJB2MJU2)](https://codecov.io/gh/element-hq/element-x-ios)

# Element X iOS

Element X iOS is the next-generation [Matrix](https://matrix.org/) client provided by [Element](https://element.io/).

Compared to the previous-generation [Element Classic](https://github.com/element-hq/element-ios), it is a total rewrite using the [Matrix Rust SDK](https://github.com/matrix-org/matrix-rust-sdk) underneath and targeting devices running iOS 18+.

## Rust SDK

Element X leverages the [Matrix Rust SDK](https://github.com/matrix-org/matrix-rust-sdk) through an FFI layer exposed as a [swift package](https://github.com/matrix-org/matrix-rust-components-swift) that the final client can directly import and use. We're doing this as a way to share code between platforms, with [Element X Android](https://github.com/element-hq/element-x-android) using the same SDK.

## Status

This project is actively developed and supported. New users are recommended to use Element X instead of the previous-generation app.

## Contributing

Please see our [contribution guide](CONTRIBUTING.md).

Come chat with the community in the dedicated Matrix [room](https://matrix.to/#/#element-x-ios:matrix.org).

## Build instructions

Please refer to the [setting up a development environment](CONTRIBUTING.md#setting-up-a-development-environment) section from the [contribution guide](CONTRIBUTING.md).

### `dual1208` fork configuration

The physical-device build is named **Element X tcno** and uses bundle identifier `com.dual1208.elementx`, app group `group.com.dual1208.elementx`, and Apple team `GQZ5664B67`. It defaults to `https://8.163.2.191`, whose Matrix Authentication Service issuer is `https://8.163.2.191/auth/`. MAS has a static public-client registration for client ID `01M2VM6HEE7G54S8RFEJEFK7DT` and redirect URI `com.dual1208.elementx:/oauth`, so sign-in does not depend on an Apple App Site Association file for the IP address.

With Xcode 27 selected and the paired iPhone connected, export its identifier as `IOS_DEVICE_ID` and run `just deploy` to build, install, launch, verify the process, and capture a screenshot. For example:

```shell
export IOS_DEVICE_ID="<paired physical iPhone UDID>"
just deploy
```

The identifier is intentionally kept out of the public fork. Each device operation requires it, enforces the local iOS 26.7 debug gate, checks that the gate's exact destination matches `IOS_DEVICE_ID`, and verifies that the connected target is physical hardware. Formatting and linting do not require a device identifier.

Build, test, archive, export, and validation recipes run Xcode through macOS background scheduling and limit Xcode's build concurrency to one task so the 8 GB development Mac stays responsive.

The base fork was validated on September 18, 2026 with Xcode 27.0 and iOS 26.7: the Debug app built successfully, signed as `GQZ5664B67.com.dual1208.elementx`, installed and launched on the gated physical iPhone, completed the static MAS custom-scheme authorization flow, and reached the signed-in Chats screen. For the managed-family revision, the gated physical-iPhone run on September 20, 2026 passed all 75 focused tests across Analytics, Authentication Start, Home, Identity Confirmation, and Navigation Split, with no failures or skips. The build 3 UI and localization update subsequently passed all 42 focused Authentication Start, Home, and Localization tests on the same gated physical iPhone running iOS 26.7, with no failures or skips. Its Release archive, exports, installation, and launch remain pending. A direct install of the 582 MB Debug app stalled in CoreDevice, but the 301 MB Release app re-exported with development signing installed over the existing app without removing its container. The device then reported build 2, and the gated launch plus process check succeeded. Use `just export-device-archive` followed by `just install-device-archive` to reproduce this smaller physical install path.

The managed-family build keeps the homeserver fixed and opens the configured private encrypted Family room after the SDK reports that the restored session is verified and key recovery is enabled. If recovery is disabled or incomplete, it opens the existing chat-backup settings flow. It accepts an invitation automatically only when its room ID matches the configured Family room. Room creation, directory/search/spaces navigation, unrelated room deep links, leaving the Family room, and the onboarding verification-skip/reset actions are guarded; Settings remains available for supervised account, verification, and recovery repair. Existing sessions and SDK stores are preserved, including an incompatible saved session, which stays on the repair screen instead of being cleared.

This family variant disables Element's PostHog, Sentry, Element Call analytics, and Rageshake destinations. It does not embed account passwords, recovery keys, or other private credentials.

For App Store preparation, `just archive` creates a Release archive for a generic iOS device, `just export-archive` exports it with `Config/AppStoreExportOptions.plist`, and `just validate-archive` asks Apple's service to validate that archive without submitting it for review. Override `IOS_ARCHIVE_PATH`, `IOS_EXPORT_PATH`, `IOS_EXPORT_OPTIONS_PLIST`, or `IOS_VALIDATION_OPTIONS_PLIST` when needed. On September 20, 2026, all three recipes succeeded through automatic provisioning and the configured App Store Connect record. The exported IPA is signed by the team's Apple cloud-managed Distribution certificate and has `aps-environment=production`, `get-task-allow=false`, the fork's app group and keychain group, and only `applinks:matrix.to` as its associated domain. Validation reported non-blocking missing-dSYM warnings for MapLibre, Sentry, YbridOgg, and YbridOpus; resolve those before relying on crash symbolication. Version 26.09.1 build 2 was then uploaded to App Store Connect, finished processing, and was attached to the saved manual-release draft. It has not been submitted for App Review, invited to testing, or released.

This fork cannot read Element Classic's upstream app-group or keychain containers, so Classic account migration is unavailable. The paid development team is also not approved for Apple's Notification Filtering entitlement; the entitlement is omitted while the notification service extension remains enabled. Production push additionally requires independent APNs and Sygnal credentials for this bundle and topic. The fork cannot inherit Element's upstream push credentials. The bare-IP associated-domain entry is omitted because authentication uses the configured custom-scheme redirect; the inherited `matrix.to` universal-link association remains.

Before App Store submission, replace or obtain permission for the inherited Element name and icon assets, verify every declared entitlement and privacy-manifest/App Privacy answer against the final services, and have the app owner confirm the inherited `ITSAppUsesNonExemptEncryption=false` export-compliance answer. Unlisted distribution still requires a complete app record, App Review approval, and Apple's separate unlisted-app request.

## Support

When you are experiencing an issue on Element X iOS, please first search in [GitHub issues](https://github.com/element-hq/element-x-ios/issues)
and then in [#element-x-ios:matrix.org](https://matrix.to/#/#element-x-ios:matrix.org).
If after your research you still have a question, ask at [#element-x-ios:matrix.org](https://matrix.to/#/#element-x-ios:matrix.org). Otherwise feel free to create a GitHub issue if you encounter a bug or a crash, by explaining clearly in detail what happened. You can also perform bug reporting (Rageshake) from the Element application by going to the application settings. This is especially recommended when you encounter a crash.

## Forking

Please read our [forking guide](docs/FORKING.md).

## Copyright & License

Copyright (c) 2025 - 2026 Element Creations Ltd.
Copyright (c) 2022 - 2025 New Vector Ltd.

This software is dual licensed by Element Creations Ltd (Element). It can be used either:

(1) for free under the terms of the GNU Affero General Public License (as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version); OR

(2) under the terms of a paid-for Element Commercial License agreement between you and Element (the terms of which may vary depending on what you and Element have agreed to). 

Unless required by applicable law or agreed to in writing, software distributed under the Licenses is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the Licenses for the specific language governing permissions and limitations under the Licenses.
