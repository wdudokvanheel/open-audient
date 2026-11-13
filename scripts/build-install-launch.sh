#!/bin/bash
# Build the current checkout, install a local app bundle, and launch its GUI.
set -euo pipefail

[[ "$(/usr/bin/uname -s)" == Darwin ]] || { echo 'This script requires macOS.' >&2; exit 1; }
project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
applications_dir="${HOME:?HOME must be set}/Applications"
destination="$applications_dir/OpenAudient.app"
bundle_id='org.openaudient.OpenAudient'
mkdir -p "$applications_dir"
lock_dir="$applications_dir/.openaudient-install.lock"
mkdir "$lock_dir" 2>/dev/null || {
    echo "Another install may be running. If it was interrupted, remove $lock_dir after checking." >&2
    exit 1
}
stage=''
cleanup() {
    if [[ -n "$stage" && -d "$stage/previous.app" ]]; then
        echo "Previous app retained at $stage/previous.app" >&2
    elif [[ -n "$stage" ]]; then
        rm -rf "$stage"
    fi
    rmdir "$lock_dir"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM HUP

# Refuse symlinks, files, and a different application's bundle at this path.
check_destination() {
    [[ ! -L "$destination" ]] || { echo "Refusing symlink: $destination" >&2; return 1; }
    if [[ -e "$destination" ]]; then
        [[ -d "$destination" && "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$destination/Contents/Info.plist")" == "$bundle_id" ]] || {
            echo "Refusing to replace an unrecognized app: $destination" >&2
            return 1
        }
    fi
}
check_destination
cd "$project_dir"
echo 'Building release product oa from the current checkout...'
/usr/bin/xcrun swift build -c release --product oa
bin_dir="$(/usr/bin/xcrun swift build -c release --show-bin-path)"
stage="$(mktemp -d "$applications_dir/.openaudient-install.XXXXXX")"
bundle="$stage/OpenAudient.app"
mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources"
install -m 755 "$bin_dir/oa" "$bundle/Contents/MacOS/oa"

# Build a complete macOS icon from the same red slider mark used in the app header.
icon_source="$project_dir/Resources/AppIcon.svg"
iconset="$stage/AppIcon.iconset"
[[ -f "$icon_source" ]] || { echo "Missing app icon source: $icon_source" >&2; exit 1; }
mkdir -p "$iconset"
for spec in \
    '16 icon_16x16.png' '32 icon_16x16@2x.png' \
    '32 icon_32x32.png' '64 icon_32x32@2x.png' \
    '128 icon_128x128.png' '256 icon_128x128@2x.png' \
    '256 icon_256x256.png' '512 icon_256x256@2x.png' \
    '512 icon_512x512.png' '1024 icon_512x512@2x.png'; do
    read -r pixels filename <<< "$spec"
    /usr/bin/sips -s format png -z "$pixels" "$pixels" "$icon_source" --out "$iconset/$filename" >/dev/null
done
/usr/bin/iconutil -c icns "$iconset" -o "$bundle/Contents/Resources/AppIcon.icns"
cat > "$bundle/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
    <key>CFBundleDevelopmentRegion</key><string>en</string>
    <key>CFBundleExecutable</key><string>oa</string>
    <key>CFBundleIdentifier</key><string>org.openaudient.OpenAudient</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundleName</key><string>OpenAudient</string>
    <key>CFBundleDisplayName</key><string>OpenAudient</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST
/usr/bin/plutil -lint "$bundle/Contents/Info.plist"
/usr/bin/codesign --force --sign - "$bundle"
/usr/bin/codesign --verify --strict "$bundle"

# AppKit identifies the exact installed bundle, without Accessibility or desktop
# control. Ask it to terminate normally; never force-kill a process by name.
app_state() {
    /usr/bin/osascript -l JavaScript - "$destination" "$1" <<'JXA'
ObjC.import('AppKit');
function run(argv) {
    function canonical(path) {
        return $.NSString.stringWithString(path).stringByResolvingSymlinksInPath.js;
    }
    var target = canonical(argv[0]);
    function matches() {
        var apps = $.NSWorkspace.sharedWorkspace.runningApplications;
        var found = [];
        for (var i = 0; i < apps.count; i++) {
            var app = apps.objectAtIndex(i);
            if (app.bundleURL && !app.bundleURL.isNil() && canonical(app.bundleURL.path.js) === target)
                found.push(app);
        }
        return found;
    }
    if (argv[1] === 'stop') {
        matches().forEach(function(app) {
            if (!app.terminate) throw new Error('OpenAudient refused to quit; existing app preserved.');
        });
    }
    for (var attempt = 0; attempt < 60; attempt++) {
        var apps = matches();
        if (argv[1] === 'stop' && apps.length === 0) return 'Previous OpenAudient instance stopped (if running).';
        if (argv[1] === 'verify' && apps.some(function(app) { return app.finishedLaunching && !app.terminated; }))
            return 'OpenAudient launched: pid=' + apps[0].processIdentifier + ', bundle=' + target;
        // AppKit refreshes running-application state on the main run loop.
        $.NSRunLoop.mainRunLoop.runUntilDate($.NSDate.dateWithTimeIntervalSinceNow(0.25));
    }
    throw new Error(argv[1] === 'stop' ? 'OpenAudient did not quit; existing app preserved.' : 'Installed app did not finish launching.');
}
JXA
}

# The old app is touched only after the complete replacement is validated.
check_destination
app_state stop
if [[ -d "$destination" ]]; then
    mv "$destination" "$stage/previous.app"
fi
if ! mv "$bundle" "$destination"; then
    [[ ! -d "$stage/previous.app" ]] || mv "$stage/previous.app" "$destination"
    exit 1
fi
echo "Installed $destination"
/usr/bin/open "$destination"
app_state verify
# Retain the previous app on failure; remove it only after confirmed launch.
rm -rf "$stage/previous.app"
