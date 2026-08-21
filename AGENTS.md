# AGENTS.md

## Cursor Cloud specific instructions

### What this project is

`TToolsIPScanner` is a **native Apple app** (SwiftUI, iOS 18.1 / macOS 15.1 / visionOS) built with
**Xcode** (`TToolsIPScanner.xcodeproj`). There is no package manager (no SPM `Package.swift`,
CocoaPods, or Carthage); every dependency is an Apple system framework
(`SwiftUI`, `AppKit`/`UIKit`, `Network`, `SystemConfiguration`, `Darwin`). It is a self-contained
client app: **no backend, no database service, no dev server**.

### Hard platform constraint (read first)

Cloud Agent VMs run **Linux x86_64**, so the real app **cannot be built, run, or fully tested here** —
that requires **macOS + Xcode** (Apple SDKs, simulators, code signing). On macOS the standard commands are:

- Build (macOS destination): `xcodebuild -project TToolsIPScanner.xcodeproj -scheme TToolsIPScanner -destination 'platform=macOS' build`
- Build (iOS Simulator): `xcodebuild -project TToolsIPScanner.xcodeproj -scheme TToolsIPScanner -destination 'platform=iOS Simulator,name=iPhone 16' build`
- Test: `xcodebuild test -project TToolsIPScanner.xcodeproj -scheme TToolsIPScanner -destination 'platform=iOS Simulator,name=iPhone 16'`
- Run in dev: open the project in Xcode, pick a destination, press ⌘R.

There is **nothing to install for the real project on Linux**, which is why the startup update
script is intentionally a no-op.

### What CAN be validated on the Linux VM (portable subset)

The `Foundation`-only core logic (models + parsing/validation utilities) compiles and unit-tests on
Linux with an open-source Swift toolchain, via a **throwaway SPM scaffold kept outside the repo**
(so the repository itself is never modified). This is useful for quick logic-level checks; it does
**not** cover UI, networking (`NetworkScanner` + its `Network`/`Darwin` extensions), `SwiftUI`, or
`SettingsManager` (which depends on the `SwiftUI`-importing `NetworkConstants`).

Reproduce it (optional; toolchain is NOT installed by the update script because it is a ~1 GB system
dependency, not a project dependency):

```bash
# 1. Install Swift for Linux (once per VM)
cd /tmp && curl -fsSL -O https://download.swift.org/swiftly/linux/swiftly-$(uname -m).tar.gz \
  && tar zxf swiftly-$(uname -m).tar.gz && ./swiftly init --quiet-shell-followup --assume-yes
sudo apt-get -y install gnupg2 libcurl4-openssl-dev libpython3-dev libxml2-dev libncurses-dev libz3-dev
. "$HOME/.local/share/swiftly/env.sh" && hash -r   # provides `swift` (6.3.x)

# 2. Build a scaffold in /tmp (outside the repo) containing ONLY the Foundation-only files:
#    Sources/TToolsIPScanner/  <- Models/{DeviceAlias,DeviceInfo,DeviceStatus,ScanError,SortOption,TableSettings}.swift
#                                 Utilities/{DeviceStatusResolver,DNSCache,IPAddressValidator,OUIParser,PortListParser,PropertyWrappers}.swift
#                                 plus a trimmed NetworkConstants (drop the SwiftUI `Color` portSymbols map)
#    Tests/TToolsIPScannerTests/ <- the matching XCTest files
#    Package.swift with a library target `TToolsIPScanner` (+ optional executable) and a test target.
# 3. swift test   # 226 tests pass across 8 suites
```

### Known pre-existing test bug (not a setup problem)

`TToolsIPScannerTests/PropertyWrappersTests.swift` constructs `DeviceInfo(... vendor: "", status: .active)`,
but the current `DeviceInfo` model uses `manufacturer:`/`isExpanded:` and `DeviceStatus` has no
`.active` case. This file will **not compile as-is on macOS or Linux**; exclude it from the portable
scaffold. Fixing it is out of scope for environment setup.

### Notes

- The root `*.md` files (`CODE_REVIEW.md`, `SUMMARY.md`, `*_IMPLEMENTATION.md`, etc., mostly German)
  are code-review artifacts, not setup docs.
- `oui.txt` (MAC-vendor DB) ships as a bundled app resource; `UserDefaults` stores settings; there is
  no external service to run.
