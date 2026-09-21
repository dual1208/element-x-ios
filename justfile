set shell := ["/bin/zsh", "-euc"]

device_id := env_var_or_default("IOS_DEVICE_ID", "")
device_kind := env_var_or_default("IOS_DEVICE_KIND", "iphone")
destination := "platform=iOS,id=" + device_id
scheme := "ElementX"
configuration := "Debug"
derived_data := "DerivedData/tcnowifi"
build_jobs := env_var_or_default("IOS_BUILD_JOBS", "2")
app_path := derived_data + "/Build/Products/Debug-iphoneos/ElementX.app"
bundle_id := "com.dual1208.elementx"
xcodebuild := "/usr/bin/xcodebuild"
archive_path := env_var_or_default("IOS_ARCHIVE_PATH", ".codex-archives/ElementX.xcarchive")
export_path := env_var_or_default("IOS_EXPORT_PATH", ".codex-archives/export")
export_options := env_var_or_default("IOS_EXPORT_OPTIONS_PLIST", "Config/AppStoreExportOptions.plist")
validation_options := env_var_or_default("IOS_VALIDATION_OPTIONS_PLIST", "Config/AppStoreValidationOptions.plist")
device_export_path := env_var_or_default("IOS_DEVICE_EXPORT_PATH", ".codex-archives/device-export")
device_export_options := env_var_or_default("IOS_DEVICE_EXPORT_OPTIONS_PLIST", "Config/DeviceExportOptions.plist")

default:
    @just --list

device:
    test -n "$IOS_DEVICE_ID" || { print -u2 'Set IOS_DEVICE_ID to the paired physical Apple device UDID.'; exit 1; }
    case "{{ device_kind }}" in iphone|ipad) ;; *) print -u2 'Set IOS_DEVICE_KIND to iphone or ipad.'; exit 1 ;; esac
    gate_output=$(/Users/xie/.local/bin/apple-debug-check {{ device_kind }}); print -r -- "$gate_output"; print -r -- "$gate_output" | rg -F -- "-destination 'platform=iOS,id=$IOS_DEVICE_ID'"
    xcrun devicectl list devices | rg -F "$IOS_DEVICE_ID" | rg '(available|connected).*physical'

generate:
    xcodegen

fmt:
    swiftformat .

lint:
    swiftformat --lint .
    swiftlint

build:
    just device
    mkdir -p .codex-logs
    set -o pipefail; {{ xcodebuild }} -project ElementX.xcodeproj -scheme {{ scheme }} -configuration {{ configuration }} -destination '{{ destination }}' -derivedDataPath {{ derived_data }} -jobs {{ build_jobs }} ARCHS=arm64 ONLY_ACTIVE_ARCH=YES -disableAutomaticPackageResolution -skipPackageUpdates -allowProvisioningUpdates build 2>&1 | tee .codex-logs/device-build.log | xcbeautify

test-managed:
    just device
    mkdir -p .codex-logs
    set -o pipefail; {{ xcodebuild }} -project ElementX.xcodeproj -scheme {{ scheme }} -configuration {{ configuration }} -destination '{{ destination }}' -derivedDataPath {{ derived_data }} -jobs 1 -disableAutomaticPackageResolution -skipPackageUpdates -allowProvisioningUpdates test -only-testing:UnitTests/AnalyticsTests -only-testing:UnitTests/AuthenticationStartScreenViewModelTests -only-testing:UnitTests/HomeScreenViewModelTests -only-testing:UnitTests/IdentityConfirmationScreenViewModelTests -only-testing:UnitTests/NavigationSplitCoordinatorTests 2>&1 | tee .codex-logs/managed-tests.log | xcbeautify

install:
    just device
    test -d {{ app_path }}
    mkdir -p .codex-logs
    xcrun devicectl device install app --device {{ device_id }} --timeout 60 {{ app_path }} 2>&1 | tee .codex-logs/device-install.log

launch:
    just device
    mkdir -p .codex-logs
    xcrun devicectl device process launch --device {{ device_id }} --timeout 30 --terminate-existing {{ bundle_id }} 2>&1 | tee .codex-logs/device-launch.log

verify-launch:
    just device
    mkdir -p .codex-logs
    xcrun devicectl device info processes --device {{ device_id }} --timeout 30 --search ElementX --json-output .codex-logs/device-processes.json | tee .codex-logs/device-processes.log

screenshot:
    just device
    mkdir -p .codex-logs
    xcrun devicectl device capture screenshot --device {{ device_id }} --timeout 30 --destination .codex-logs/element-x-launch.png | tee .codex-logs/device-screenshot.log

deploy:
    just build
    just install
    just launch
    just verify-launch

entitlements:
    test -d {{ app_path }}
    codesign -d --entitlements :- {{ app_path }}

archive:
    mkdir -p "$(dirname {{ archive_path }})" .codex-logs
    set -o pipefail; {{ xcodebuild }} -project ElementX.xcodeproj -scheme {{ scheme }} -configuration Release -destination 'generic/platform=iOS' -archivePath {{ archive_path }} -derivedDataPath {{ derived_data }} -jobs {{ build_jobs }} ARCHS=arm64 ONLY_ACTIVE_ARCH=YES -disableAutomaticPackageResolution -skipPackageUpdates -allowProvisioningUpdates archive 2>&1 | tee .codex-logs/archive.log | xcbeautify

export-archive:
    test -d {{ archive_path }}
    test -f {{ export_options }}
    mkdir -p {{ export_path }} .codex-logs
    set -o pipefail; {{ xcodebuild }} -exportArchive -archivePath {{ archive_path }} -exportPath {{ export_path }} -exportOptionsPlist {{ export_options }} -allowProvisioningUpdates 2>&1 | tee .codex-logs/export.log | xcbeautify

validate-archive:
    test -d {{ archive_path }}
    test -f {{ validation_options }}
    mkdir -p .codex-archives/validation .codex-logs
    set -o pipefail; {{ xcodebuild }} -exportArchive -archivePath {{ archive_path }} -exportPath .codex-archives/validation -exportOptionsPlist {{ validation_options }} -allowProvisioningUpdates 2>&1 | tee .codex-logs/validation.log | xcbeautify

export-device-archive:
    test -d {{ archive_path }}
    test -f {{ device_export_options }}
    mkdir -p {{ device_export_path }} .codex-logs
    set -o pipefail; {{ xcodebuild }} -exportArchive -archivePath {{ archive_path }} -exportPath {{ device_export_path }} -exportOptionsPlist {{ device_export_options }} -allowProvisioningUpdates 2>&1 | tee .codex-logs/device-export.log | xcbeautify

install-device-archive:
    just device
    test -f {{ device_export_path }}/ElementX.ipa
    mkdir -p .codex-archives .codex-logs
    install_root=$(mktemp -d .codex-archives/device-install.XXXXXX); \
        ditto -x -k {{ device_export_path }}/ElementX.ipa "$install_root"; \
        app_path=$(/usr/bin/find "$install_root/Payload" -maxdepth 1 -name '*.app' -type d -print -quit); \
        test -n "$app_path"; \
        xcrun devicectl device install app --device {{ device_id }} --timeout 180 "$app_path" 2>&1 | tee .codex-logs/device-install-archive.log

ci: build
