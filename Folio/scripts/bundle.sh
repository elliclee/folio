#!/bin/zsh
# Builds dist/Folio.app: release binary + icon + Info.plist with
# md/markdown file associations, ad-hoc signed. Pass --dmg to also
# produce dist/Folio.dmg.
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="Folio"
# Single source of truth is the VERSION file. FOLIO_VERSION (e.g. a CI
# git tag) overrides it; a leading "v" is stripped either way.
VERSION="${FOLIO_VERSION:-$(cat VERSION)}"
VERSION="${VERSION#v}"
BUNDLE_ID="com.ellic.folio"
DIST="dist"
APP="$DIST/$APP_NAME.app"
ICON_SRC="assets/Folio.icns"

echo "==> swift build -c release"
swift build -c release

echo "==> assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/release/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
cp "$ICON_SRC" "$APP/Contents/Resources/$APP_NAME.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleExecutable</key>
	<string>$APP_NAME</string>
	<key>CFBundleIconFile</key>
	<string>$APP_NAME</string>
	<key>CFBundleIdentifier</key>
	<string>$BUNDLE_ID</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>$APP_NAME</string>
	<key>CFBundleDisplayName</key>
	<string>$APP_NAME</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>$VERSION</string>
	<key>CFBundleVersion</key>
	<string>$VERSION</string>
	<key>LSMinimumSystemVersion</key>
	<string>15.0</string>
	<key>LSApplicationCategoryType</key>
	<string>public.app-category.productivity</string>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>NSPrincipalClass</key>
	<string>NSApplication</string>
	<key>NSHumanReadableCopyright</key>
	<string>© 2026 ellic</string>
	<key>CFBundleDocumentTypes</key>
	<array>
		<dict>
			<key>CFBundleTypeName</key>
			<string>Markdown Document</string>
			<key>CFBundleTypeRole</key>
			<string>Editor</string>
			<key>LSHandlerRank</key>
			<string>Default</string>
			<key>CFBundleTypeExtensions</key>
			<array>
				<string>md</string>
				<string>markdown</string>
			</array>
			<key>CFBundleTypeIconFile</key>
			<string>$APP_NAME</string>
		</dict>
	</array>
</dict>
</plist>
PLIST

echo "==> codesign (ad-hoc)"
codesign --force --sign - "$APP"

echo "==> registering with Launch Services"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP"

if [[ "${1:-}" == "--dmg" ]]; then
    echo "==> building $DIST/$APP_NAME.dmg"
    rm -f "$DIST/$APP_NAME.dmg"
    STAGING=$(mktemp -d)
    cp -R "$APP" "$STAGING/"
    ln -s /Applications "$STAGING/Applications"

    # First-launch note: the app is ad-hoc signed (not notarized), so
    # Gatekeeper quarantines it. The xattr command clears the quarantine.
    cat > "$STAGING/Readme.rtf" <<'RTF'
{\rtf1\ansi\ansicpg1252\cocoartf2639
\cocoatextscaling0\cocoaplatform0{\fonttbl\f0\fswiss\fcharset0 Helvetica-Bold;\f1\fswiss\fcharset0 Helvetica;\f2\fmodern\fcharset0 Menlo-Regular;}
{\colortbl;\red255\green255\blue255;\red20\green20\blue20;\red120\green120\blue120;}
\margl1440\margr1440\vieww11000\viewh9000\viewkind0
\pard\sa280\qc\f0\fs36\cf2 Folio\

\pard\sa200\f1\fs26\cf2 Folio is ad-hoc signed (not yet notarized), so macOS quarantines it on first download.\

\pard\sa120\f0\fs26\cf2 To open it:\

\pard\sa120\f1\fs26\cf2 1. Drag\b  Folio\b0  onto the\b  Applications\b0  folder.\
2. Open\b  Terminal\b0  and run:\

\pard\sa200\f2\fs24\cf2 xattr -dr com.apple.quarantine "/Applications/Folio.app"\

\pard\sa200\f1\fs26\cf2 3. Launch Folio normally.\

\pard\sa0\f1\fs22\cf3 You only need to do this once. Alternatively, right-click Folio and choose Open, then confirm.\
}
RTF

    hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING" -ov -format UDZO "$DIST/$APP_NAME.dmg"
    rm -rf "$STAGING"
fi

echo "Done: $APP"
