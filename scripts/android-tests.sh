#!/bin/bash
# Runs the Kotlin tests on an Android emulator: cross-compiles the package with the Swift SDK for
# Android, packages it with the Swift runtime, and runs Tests/shared as instrumented tests.
#
#   scripts/android-tests.sh [avd]       # default: the first AVD `emulator -list-avds` prints
#
# Needs ANDROID_HOME (or ~/Library/Android/sdk), an arm64 AVD, the Swift SDK for Android and a matching
# swift.org toolchain (see README.md; override with -PswiftToolchain=... -PswiftAndroidSdk=...).
set -euo pipefail
cd "$(dirname "$0")/.."

ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
adb="$ANDROID_HOME/platform-tools/adb"
avd="${1:-$("$ANDROID_HOME/emulator/emulator" -list-avds | head -1)}"

if ! "$adb" devices | grep -q "^emulator-.*device$"; then
  echo "Starting emulator $avd"
  "$ANDROID_HOME/emulator/emulator" -avd "$avd" -no-window -no-audio -no-boot-anim -no-snapshot-save > /dev/null 2>&1 &
  "$adb" wait-for-device
  until [ "$("$adb" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; do sleep 2; done
fi

./gradlew :android:connectedDebugAndroidTest "${@:2}"
