set shell := ["/bin/zsh", "-euc"]

device_id := env_var_or_default("IOS_DEVICE_ID", "")
destination := "platform=iOS,id=" + device_id
scheme := "ElementX"
configuration := "Debug"
derived_data := "DerivedData/tcnowifi"
app_path := derived_data + "/Build/Products/Debug-iphoneos/ElementX.app"
bundle_id := "com.dual1208.elementx"

default:
    @just --list

device:
    test -n "$IOS_DEVICE_ID" || { print -u2 'Set IOS_DEVICE_ID to the paired physical iPhone UDID.'; exit 1; }
    gate_output=$(/Users/xie/.local/bin/apple-debug-check iphone); print -r -- "$gate_output"; print -r -- "$gate_output" | rg -F -- "-destination 'platform=iOS,id=$IOS_DEVICE_ID'"
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
    set -o pipefail; xcodebuild -project ElementX.xcodeproj -scheme {{ scheme }} -configuration {{ configuration }} -destination '{{ destination }}' -derivedDataPath {{ derived_data }} -disableAutomaticPackageResolution -skipPackageUpdates -allowProvisioningUpdates build 2>&1 | tee .codex-logs/device-build.log | xcbeautify

install:
    just device
    test -d {{ app_path }}
    mkdir -p .codex-logs
    xcrun devicectl device install app --device {{ device_id }} {{ app_path }} 2>&1 | tee .codex-logs/device-install.log

launch:
    just device
    mkdir -p .codex-logs
    xcrun devicectl device process launch --device {{ device_id }} --terminate-existing {{ bundle_id }} 2>&1 | tee .codex-logs/device-launch.log

verify-launch:
    just device
    mkdir -p .codex-logs
    xcrun devicectl device info processes --device {{ device_id }} --search ElementX --json-output .codex-logs/device-processes.json | tee .codex-logs/device-processes.log

screenshot:
    just device
    mkdir -p .codex-logs
    xcrun devicectl device capture screenshot --device {{ device_id }} --destination .codex-logs/element-x-launch.png | tee .codex-logs/device-screenshot.log

deploy:
    just build
    just install
    just launch
    just verify-launch
    just screenshot

entitlements:
    test -d {{ app_path }}
    codesign -d --entitlements :- {{ app_path }}

ci: lint build
