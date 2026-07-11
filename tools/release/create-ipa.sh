#!/bin/sh
set -eu

CLANG_PATH="$(xcrun --sdk iphoneos --find clang)"
SDK_PATH="$(xcrun --sdk iphoneos --show-sdk-path)"
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)"
ARCHIVE_DIR="${BAKLAFOX_ARCHIVE_DIR:-$ROOT_DIR/.build/BaklaFox.xcarchive}"
APP_DIR="$ARCHIVE_DIR/Products/Applications"
OUTPUT_DIR="${BAKLAFOX_OUTPUT_DIR:-$ROOT_DIR/dist}"
WORK_ROOT="${BAKLAFOX_WORK_ROOT:-$ROOT_DIR/.build/.BaklaFox-package-v16.$$}"
LOCK_DIR="$ROOT_DIR/.build/release-package-v16.lock"

LOADER_SOURCE="$ROOT_DIR/browser/Loader/main.m"
MAIN_ENTITLEMENTS="$ROOT_DIR/browser/Reynard/Entitlements/Reynard.legacy-sandbox.entitlements"
HELPER_ENTITLEMENTS="$ROOT_DIR/browser/Helper/Entitlements/Reynard-Helper.legacy-sandbox.entitlements"
OPENIN_ENTITLEMENTS="$ROOT_DIR/browser/Reynard/Entitlements/Reynard.entitlements"
SWIFT_CONCURRENCY_SOURCE="${BAKLAFOX_SWIFT_CONCURRENCY_SOURCE:-/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift-5.5/iphoneos/libswift_Concurrency.dylib}"
EVENT_DISPATCHER_SOURCE="$ROOT_DIR/browser/GeckoView/Events/EventDispatcher.swift"
BUILD_VERSION="${BAKLAFOX_BUILD_VERSION:-20260710.16}"
FIX_VERSION="taurine-deferred-gecko-mainthread-dispatch-v16"
ARCHITECTURE="deferred-gecko-tweaks-v16-mainthread-dispatch"

cleanup() {
    rm -rf "$WORK_ROOT" "$LOCK_DIR" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

mkdir -p "$ROOT_DIR/.build" "$OUTPUT_DIR"
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    lock_pid="$(cat "$LOCK_DIR/pid" 2>/dev/null || true)"
    if [ -n "$lock_pid" ] && kill -0 "$lock_pid" 2>/dev/null; then
        echo "Another BaklaFox package job is running (PID $lock_pid)" >&2
        exit 75
    fi
    rm -rf "$LOCK_DIR"
    mkdir "$LOCK_DIR"
fi
echo "$$" > "$LOCK_DIR/pid"

[ -d "$APP_DIR" ] || { echo "Missing archive output at $APP_DIR" >&2; exit 1; }
SOURCE_APP="$(find "$APP_DIR" -maxdepth 1 -type d -name '*.app' | head -n 1)"
[ -n "$SOURCE_APP" ] || { echo "No .app found in $APP_DIR" >&2; exit 1; }
[ -f "$LOADER_SOURCE" ] || { echo "Missing loader source: $LOADER_SOURCE" >&2; exit 1; }

rm -f \
    "$OUTPUT_DIR/BaklaFox.ipa" \
    "$OUTPUT_DIR/BaklaFox-Jailbroken.ipa" \
    "$OUTPUT_DIR/BaklaFox-TrollStore.tipa" \
    "$OUTPUT_DIR/BaklaFox-Gecko-iOS13-14-DeepFix-v16.ipa" \
    "$OUTPUT_DIR/BaklaFox-Gecko-iOS13-14-DeepFix-v16.audit.txt"
mkdir -p "$WORK_ROOT/Payload"
ditto "$SOURCE_APP" "$WORK_ROOT/Payload/BaklaFox.app"
APP="$WORK_ROOT/Payload/BaklaFox.app"

plist_executable() {
    /usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$1/Info.plist"
}

set_plist_string() {
    plist="$1"; key="$2"; value="$3"
    /usr/libexec/PlistBuddy -c "Delete :$key" "$plist" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Add :$key string $value" "$plist"
}

apply_bundle_identifiers() {
    plutil -replace CFBundleIdentifier -string com.baklalabs.BaklaFox "$APP/Info.plist"
    plutil -replace CFBundleIdentifier -string com.baklalabs.BaklaFox.Helper "$APP/PlugIns/BaklaFox Helper.appex/Info.plist"
    plutil -replace CFBundleIdentifier -string com.baklalabs.BaklaFox.OpenIn "$APP/PlugIns/OpenIn.appex/Info.plist"
}

embed_swift_backdeployment_runtime() {
    CORE="$APP/Frameworks/BaklaFoxCore.framework/BaklaFoxCore"
    DEST="$APP/Frameworks/libswift_Concurrency.dylib"

    [ -f "$CORE" ] || { echo "Missing BaklaFoxCore before Swift runtime audit" >&2; exit 1; }
    if otool -L "$CORE" | grep -q '@rpath/libswift_Concurrency.dylib'; then
        [ -f "$SWIFT_CONCURRENCY_SOURCE" ] || {
            echo "BaklaFoxCore uses Swift Task APIs, but the iOS back-deployment runtime is missing: $SWIFT_CONCURRENCY_SOURCE" >&2
            exit 1
        }
        cp "$SWIFT_CONCURRENCY_SOURCE" "$DEST"
        chmod 0755 "$DEST"
        set_plist_string "$APP/Info.plist" BaklaFoxSwiftConcurrencyBackDeployment embedded-signed-v16
    else
        rm -f "$DEST"
        set_plist_string "$APP/Info.plist" BaklaFoxSwiftConcurrencyBackDeployment not-required
    fi
}

compile_exact_loader() {
    "$CLANG_PATH" \
        -x c \
        -arch arm64 \
        -isysroot "$SDK_PATH" \
        -miphoneos-version-min=13.0 \
        -Os \
        -fvisibility=hidden \
        -Wl,-dead_strip \
        "$LOADER_SOURCE" \
        -o "$APP/BaklaFox"
    chmod 0755 "$APP/BaklaFox"
    plutil -replace CFBundleExecutable -string BaklaFox "$APP/Info.plist"
}

configure_pre_dyld_policy() {
    # Preserve Taurine/libhooker and user tweaks. They finish their pre-main
    # constructors against the tiny libSystem-only loader. Gecko/XUL is mapped
    # afterward by dlopen in the same process, so no exec/spawn reinjection path
    # exists and no global or per-app tweak state is changed.
    /usr/libexec/PlistBuddy -c 'Delete :LSEnvironment' "$APP/Info.plist" 2>/dev/null || true

    set_plist_string "$APP/Info.plist" CFBundleVersion "$BUILD_VERSION"
    set_plist_string "$APP/Info.plist" BaklaFoxPackagingArchitecture "$ARCHITECTURE"
    set_plist_string "$APP/Info.plist" BaklaFoxTweakInjectionPolicy preserve-in-process
    set_plist_string "$APP/Info.plist" BaklaFoxLegacyFixVersion "$FIX_VERSION"
    set_plist_string "$APP/Info.plist" BaklaFoxGeckoEventDispatcherThreadPolicy main-thread-serialized-v16
    /usr/libexec/PlistBuddy -c 'Delete :BaklaFoxGeckoPreserved' "$APP/Info.plist" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c 'Add :BaklaFoxGeckoPreserved bool true' "$APP/Info.plist"
    /usr/libexec/PlistBuddy -c 'Delete :BaklaFoxTweaksPreserved' "$APP/Info.plist" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c 'Add :BaklaFoxTweaksPreserved bool true' "$APP/Info.plist"
    /usr/libexec/PlistBuddy -c 'Delete :UIFileSharingEnabled' "$APP/Info.plist" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c 'Add :UIFileSharingEnabled bool true' "$APP/Info.plist"
    /usr/libexec/PlistBuddy -c 'Delete :LSSupportsOpeningDocumentsInPlace' "$APP/Info.plist" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c 'Add :LSSupportsOpeningDocumentsInPlace bool true' "$APP/Info.plist"
    set_plist_string "$APP/Info.plist" BaklaFoxGeckoThreadBridge main-queue-serialized-v16
    set_plist_string "$APP/Info.plist" BaklaFoxOpenInCompatibilityMode disabled-on-ios13-14-v16

    OPENIN_INFO="$APP/PlugIns/OpenIn.appex/Info.plist"
    /usr/libexec/PlistBuddy -c 'Delete :NSExtension:NSExtensionAttributes:NSExtensionActivationRule' "$OPENIN_INFO" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c 'Add :NSExtension:NSExtensionAttributes:NSExtensionActivationRule string FALSEPREDICATE' "$OPENIN_INFO"

    rm -f "$APP/BaklaFox.real" "$APP/ptrace_jit"
}

sign_everything() {
    find "$APP" -type f \( -perm -111 -o -name '*.dylib' \) | while IFS= read -r candidate; do
        if file "$candidate" 2>/dev/null | grep -q 'Mach-O'; then
            echo "Signing $(basename "$candidate")"
            ldid -S "$candidate"
        fi
    done

    find "$APP" -type f \( -perm -111 -o -name '*.dylib' \) | while IFS= read -r candidate; do
        if file "$candidate" 2>/dev/null | grep -q 'Mach-O 64-bit executable'; then
            chmod 0755 "$candidate"
            ldid -S"$MAIN_ENTITLEMENTS" "$candidate"
        fi
    done

    HELPER="$APP/PlugIns/BaklaFox Helper.appex/$(plist_executable "$APP/PlugIns/BaklaFox Helper.appex")"
    OPENIN="$APP/PlugIns/OpenIn.appex/$(plist_executable "$APP/PlugIns/OpenIn.appex")"
    ldid -S"$HELPER_ENTITLEMENTS" "$HELPER"
    ldid -S"$OPENIN_ENTITLEMENTS" "$OPENIN"
    ldid -S"$MAIN_ENTITLEMENTS" "$APP/BaklaFox"
}

entitlements_for() { ldid -e "$1"; }

assert_has_entitlement() {
    executable="$1"; key="$2"; label="$3"
    entitlements_for "$executable" | grep -q "<key>$key</key>" || {
        echo "Refusing to package: $label is missing $key" >&2; exit 1;
    }
}

assert_lacks_entitlement() {
    executable="$1"; key="$2"; label="$3"
    if entitlements_for "$executable" | grep -q "<key>$key</key>"; then
        echo "Refusing to package: $label contains forbidden $key" >&2; exit 1
    fi
}

verify_package() {
    [ -f "$EVENT_DISPATCHER_SOURCE" ] || { echo "Missing Gecko event dispatcher source" >&2; exit 1; }
    grep -q 'DispatchQueue.main.async' "$EVENT_DISPATCHER_SOURCE" || {
        echo "Refusing to package: Gecko dispatch is not marshalled onto the main queue" >&2; exit 1;
    }
    grep -q 'dispatchPrecondition(condition: .onQueue(.main))' "$EVENT_DISPATCHER_SOURCE" || {
        echo "Refusing to package: Gecko main-thread precondition is missing" >&2; exit 1;
    }
    EVENT_DISPATCHER_SHA256="$(shasum -a 256 "$EVENT_DISPATCHER_SOURCE" | awk '{print $1}')"

    MAIN="$APP/BaklaFox"
    CORE="$APP/Frameworks/BaklaFoxCore.framework/BaklaFoxCore"
    GECKOVIEW="$APP/Frameworks/GeckoView.framework/GeckoView"
    XUL="$APP/Frameworks/GeckoView.framework/XUL"
    CONCURRENCY="$APP/Frameworks/libswift_Concurrency.dylib"
    HELPER="$APP/PlugIns/BaklaFox Helper.appex/$(plist_executable "$APP/PlugIns/BaklaFox Helper.appex")"

    [ "$(plist_executable "$APP")" = BaklaFox ] || { echo "Wrong CFBundleExecutable" >&2; exit 1; }
    [ -f "$MAIN" ] || { echo "Missing loader" >&2; exit 1; }
    [ -f "$CORE" ] || { echo "Missing BaklaFoxCore" >&2; exit 1; }
    [ -f "$GECKOVIEW" ] || { echo "Missing GeckoView" >&2; exit 1; }
    [ -f "$XUL" ] || { echo "Missing Gecko XUL" >&2; exit 1; }
    if otool -L "$CORE" | grep -q '@rpath/libswift_Concurrency.dylib'; then
        [ -f "$CONCURRENCY" ] || {
            echo "Refusing to package: BaklaFoxCore weak-links Swift concurrency, but libswift_Concurrency.dylib is absent" >&2
            exit 1
        }
        otool -D "$CONCURRENCY" | grep -q '@rpath/libswift_Concurrency.dylib' || {
            echo "Refusing to package: embedded Swift concurrency runtime has the wrong install name" >&2
            exit 1
        }
        for symbol in _swift_task_create _swift_task_alloc _swift_task_switch; do
            nm -gU "$CONCURRENCY" | grep -q "$symbol" || {
                echo "Refusing to package: embedded Swift concurrency runtime lacks $symbol" >&2
                exit 1
            }
        done
        ldid -e "$CONCURRENCY" >/dev/null 2>&1 || {
            echo "Refusing to package: embedded Swift concurrency runtime is unsigned" >&2
            exit 1
        }
        CONCURRENCY_SIZE="$(stat -f '%z' "$CONCURRENCY")"
        CONCURRENCY_SHA256="$(shasum -a 256 "$CONCURRENCY" | awk '{print $1}')"
    else
        CONCURRENCY_SIZE=0
        CONCURRENCY_SHA256=not-required
    fi

    LOADER_SIZE="$(stat -f '%z' "$MAIN")"
    CORE_SIZE="$(stat -f '%z' "$CORE")"
    XUL_SIZE="$(stat -f '%z' "$XUL")"
    [ "$LOADER_SIZE" -lt 262144 ] || { echo "Loader is too large: $LOADER_SIZE" >&2; exit 1; }
    [ "$CORE_SIZE" -gt 1000000 ] || { echo "BaklaFoxCore is unexpectedly small" >&2; exit 1; }
    [ "$XUL_SIZE" -gt 100000000 ] || { echo "Gecko XUL is unexpectedly small" >&2; exit 1; }

    LOADER_DEPS="$(otool -L "$MAIN")"
    printf '%s\n' "$LOADER_DEPS" | grep -q '/usr/lib/libSystem.B.dylib' || { echo "Loader lacks libSystem" >&2; exit 1; }
    if printf '%s\n' "$LOADER_DEPS" | grep -Eq 'BaklaFoxCore|GeckoView|XUL|UIKit|Foundation|Swift|libobjc'; then
        echo "Loader maps UI/Gecko before main" >&2; printf '%s\n' "$LOADER_DEPS" >&2; exit 1
    fi
    if otool -l "$MAIN" | grep -q '__RESTRICT'; then
        echo "Loader unexpectedly suppresses Taurine/tweak injection" >&2; exit 1
    fi
    strings -a "$MAIN" | grep -q 'deferred-gecko-tweaks-v3-20260710' || { echo "Deferred Gecko marker missing" >&2; exit 1; }
    strings -a "$MAIN" | grep -q 'BAKLAFOX_TWEAKS_PRESERVED' || { echo "Tweak-preservation marker missing" >&2; exit 1; }
    nm -u "$MAIN" | grep -Eq '(^|[[:space:]])_dlopen$' || { echo "Loader lacks dlopen" >&2; exit 1; }
    nm -u "$MAIN" | grep -Eq '(^|[[:space:]])_dlsym$' || { echo "Loader lacks dlsym" >&2; exit 1; }
    if nm -u "$MAIN" | grep -Eq '(^|[[:space:]])(_execve|_posix_spawn|_posix_spawnp|_syscall)$'; then
        echo "Loader unexpectedly imports exec/spawn" >&2; exit 1
    fi

    otool -L "$CORE" | grep -q 'GeckoView.framework/GeckoView' || { echo "Core does not link GeckoView" >&2; exit 1; }
    otool -L "$CORE" | grep -q '@rpath/XUL' || { echo "Core does not link XUL" >&2; exit 1; }
    nm -gU "$CORE" | grep -q '_BaklaFoxCoreMain' || { echo "BaklaFoxCoreMain export missing" >&2; exit 1; }

    GECKOVIEW_SYMBOLS="$WORK_ROOT/GeckoView.symbols.txt"
    GECKOVIEW_DISASSEMBLY="$WORK_ROOT/GeckoView.disassembly.txt"
    nm -an "$GECKOVIEW" > "$GECKOVIEW_SYMBOLS"
    grep -q 'dispatchOnMain' "$GECKOVIEW_SYMBOLS" || { echo "Refusing to package: Gecko dispatcher main-thread bridge is missing" >&2; exit 1; }
    otool -tvV "$GECKOVIEW" > "$GECKOVIEW_DISASSEMBLY"
    grep -q 'Objc selector ref: isMainThread' "$GECKOVIEW_DISASSEMBLY" || { echo "Refusing to package: Gecko bridge lacks main-thread check" >&2; exit 1; }
    grep -q 'DispatchE4mainABvgZ' "$GECKOVIEW_DISASSEMBLY" || { echo "Refusing to package: Gecko bridge lacks DispatchQueue.main" >&2; exit 1; }
    grep -q 'DispatchE4sync7execut' "$GECKOVIEW_DISASSEMBLY" || { echo "Refusing to package: Gecko bridge lacks synchronous main dispatch" >&2; exit 1; }
    [ "$(/usr/libexec/PlistBuddy -c 'Print :NSExtension:NSExtensionAttributes:NSExtensionActivationRule' "$APP/PlugIns/OpenIn.appex/Info.plist")" = FALSEPREDICATE ] || { echo "Refusing to package: OpenIn legacy activation is enabled" >&2; exit 1; }

    if /usr/libexec/PlistBuddy -c 'Print :LSEnvironment:_SafeMode' "$APP/Info.plist" >/dev/null 2>&1; then
        echo "_SafeMode must not be present" >&2; exit 1
    fi
    if /usr/libexec/PlistBuddy -c 'Print :LSEnvironment:_MSSafeMode' "$APP/Info.plist" >/dev/null 2>&1; then
        echo "_MSSafeMode must not be present" >&2; exit 1
    fi

    assert_has_entitlement "$MAIN" com.apple.security.cs.allow-jit 'main Gecko process'
    assert_has_entitlement "$MAIN" com.apple.security.cs.allow-unsigned-executable-memory 'main Gecko process'
    assert_has_entitlement "$MAIN" dynamic-codesigning 'main Gecko process'
    assert_lacks_entitlement "$MAIN" platform-application 'main Gecko process'
    assert_lacks_entitlement "$MAIN" com.apple.private.security.no-sandbox 'main Gecko process'
    assert_lacks_entitlement "$MAIN" com.apple.private.persona-mgmt 'main Gecko process'
    assert_has_entitlement "$HELPER" com.apple.security.cs.allow-jit 'Gecko helper'
    assert_has_entitlement "$HELPER" dynamic-codesigning 'Gecko helper'
    assert_lacks_entitlement "$HELPER" platform-application 'Gecko helper'

    TOTAL_MACHO=0
    UNSIGNED_MACHO=0
    while IFS= read -r candidate; do
        if file "$candidate" 2>/dev/null | grep -q 'Mach-O'; then
            TOTAL_MACHO=$((TOTAL_MACHO + 1))
            if ! ldid -e "$candidate" >/dev/null 2>&1; then
                echo "Unreadable signature: $candidate" >&2
                UNSIGNED_MACHO=$((UNSIGNED_MACHO + 1))
            fi
        fi
    done <<EOF_MACHO
$(find "$APP" -type f \( -perm -111 -o -name '*.dylib' \))
EOF_MACHO
    [ "$UNSIGNED_MACHO" -eq 0 ] || { echo "$UNSIGNED_MACHO unsigned Mach-O files" >&2; exit 1; }

    MINIMUM_IOS="$(vtool -show-build "$MAIN" | awk '/minos/{print $2; exit}')"
    [ "$MINIMUM_IOS" = 13.0 ] || { echo "Unexpected minimum iOS: $MINIMUM_IOS" >&2; exit 1; }

    GECKOVIEW_UUID="$(dwarfdump --uuid "$GECKOVIEW" | awk '{print $2; exit}')"
    export MAIN CORE GECKOVIEW XUL CONCURRENCY HELPER LOADER_SIZE CORE_SIZE XUL_SIZE CONCURRENCY_SIZE CONCURRENCY_SHA256 TOTAL_MACHO UNSIGNED_MACHO MINIMUM_IOS LOADER_DEPS EVENT_DISPATCHER_SHA256 GECKOVIEW_UUID
}

apply_bundle_identifiers
compile_exact_loader
configure_pre_dyld_policy
embed_swift_backdeployment_runtime
sign_everything
verify_package

FINAL_IPA="$OUTPUT_DIR/BaklaFox-Gecko-iOS13-14-DeepFix-v16.ipa"
(cd "$WORK_ROOT" && zip -qry "$FINAL_IPA" Payload -x '._*' '.DS_Store' '__MACOSX')
unzip -t "$FINAL_IPA" >/tmp/BaklaFox-v16-unzip-test.txt
cp "$FINAL_IPA" "$OUTPUT_DIR/BaklaFox-Jailbroken.ipa"
cp "$FINAL_IPA" "$OUTPUT_DIR/BaklaFox.ipa"
cp "$FINAL_IPA" "$OUTPUT_DIR/BaklaFox-TrollStore.tipa"

SHA256="$(shasum -a 256 "$FINAL_IPA" | awk '{print $1}')"
IPA_SIZE="$(stat -f '%z' "$FINAL_IPA")"
AUDIT="$OUTPUT_DIR/BaklaFox-Gecko-iOS13-14-DeepFix-v16.audit.txt"
{
    echo "BaklaFox Gecko iOS 13/14 Deep Fix v16"
    echo "IPA=$FINAL_IPA"
    echo "SHA256=$SHA256"
    echo "IPA_BYTES=$IPA_SIZE"
    echo "BUILD_VERSION=$BUILD_VERSION"
    echo "MINIMUM_IOS=$MINIMUM_IOS"
    echo "ARCHITECTURE=$ARCHITECTURE"
    echo "LOADER_BYTES=$LOADER_SIZE"
    echo "CORE_BYTES=$CORE_SIZE"
    echo "XUL_BYTES=$XUL_SIZE"
    echo "SWIFT_CONCURRENCY_BYTES=$CONCURRENCY_SIZE"
    echo "SWIFT_CONCURRENCY_SHA256=$CONCURRENCY_SHA256"
    echo "SWIFT_CONCURRENCY_BACKDEPLOYMENT=verified"
    echo "GECKO_THREAD_BRIDGE=main-queue-serialized-v16"
    echo "OPENIN_LEGACY_ACTIVATION=disabled"
    echo "GECKO_EVENT_DISPATCHER_THREAD_POLICY=main-thread-serialized-v16"
    echo "GECKO_EVENT_DISPATCHER_SOURCE_SHA256=$EVENT_DISPATCHER_SHA256"
    echo "GECKOVIEW_UUID=$GECKOVIEW_UUID"
    echo "MACHO_COUNT=$TOTAL_MACHO"
    echo "UNSIGNED_MACHO_COUNT=$UNSIGNED_MACHO"
    echo "GECKO_PRESERVED=true"
    echo "TWEAKS_PRESERVED=true"
    echo "PER_APP_TWEAK_INJECTION_SUPPRESSED=false"
    echo "GLOBAL_TWEAK_STATE_CHANGED=false"
    echo "EXEC_WRAPPER=false"
    echo "ROOT_PTRACE_HELPER=false"
    echo "ZIP_INTEGRITY=passed"
    echo "LOADER_DEPENDENCIES:"
    printf '%s\n' "$LOADER_DEPS"
    echo "MAIN_ENTITLEMENTS:"
    entitlements_for "$MAIN"
} > "$AUDIT"

printf '%s\n' "Built $FINAL_IPA"
printf '%s\n' "SHA256=$SHA256"
printf '%s\n' "AUDIT=$AUDIT"
tail -1 /tmp/BaklaFox-v16-unzip-test.txt
