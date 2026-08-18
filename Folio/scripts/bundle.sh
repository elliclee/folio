#!/bin/zsh
# Builds dist/Folio.app: release binary + icon + Info.plist with
# md/markdown file associations. Signed with Developer ID and notarized
# when that identity is in the keychain, ad-hoc otherwise. Pass --dmg to
# also produce dist/Folio.dmg.
#
# Notarization credentials live in scripts/.env.signing, which .gitignore
# already covers via the `.env*` rule — this repo is public, so they must
# never be inlined here:
#
#     ASC_KEY_ID=XXXXXXXXXX
#     ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
#     ASC_KEY="$HOME/.appstoreconnect/private_keys/AuthKey_XXXXXXXXXX.p8"
#
# Without a Developer ID identity the app is ad-hoc signed exactly as
# before, so a plain `./scripts/bundle.sh` still works on any machine.
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

[[ -f scripts/.env.signing ]] && source scripts/.env.signing

# Developer ID Application is the only identity Gatekeeper accepts for
# apps distributed outside the Mac App Store. Apple Development and Apple
# Distribution certificates are useless here — the former only covers
# registered devices, the latter only the store.
#
# A team can hold two Developer ID certificates with the *identical* common
# name — one issued by Apple's G1 sub-CA, one by G2 — which makes
# `codesign -s <name>` fail with "ambiguous (matches multiple identities)".
# So resolve to a SHA-1 hash and prefer the G2 issue: a G1 leaf's validity is
# capped at the G1 sub-CA's own 2027-02-01 expiry, G2 runs to 2031.
SIGN_ID=""      # SHA-1 hash of the identity to sign with
SIGN_DESC=""    # human-readable, for the progress line

pick_developer_id() {
    local dir hash desc
    dir=$(mktemp -d)
    # -Z prefixes each certificate with its hashes; split on those markers so
    # every PEM block lands in a file named after its own SHA-1.
    security find-certificate -a -c "Developer ID Application" -p -Z 2>/dev/null \
        | awk -v dir="$dir" '
            /^SHA-1 hash: / { hash = $3 }
            /^-----BEGIN CERTIFICATE-----/ { out = dir "/" hash ".pem" }
            out { print > out }
            /^-----END CERTIFICATE-----/ { out = "" }
        '
    for pem in "$dir"/*.pem(N); do
        hash=${${pem:t}:r}
        # A certificate whose private key is missing cannot sign — skip it.
        security find-identity -v -p codesigning | grep -q "$hash" || continue
        desc="expires $(openssl x509 -in "$pem" -noout -enddate | cut -d= -f2)"
        if openssl x509 -in "$pem" -noout -issuer | grep -q 'OU *= *G2'; then
            SIGN_ID="$hash"; SIGN_DESC="G2, $desc"
            break
        elif [[ -z "$SIGN_ID" ]]; then
            SIGN_ID="$hash"; SIGN_DESC="G1, $desc"
        fi
    done
    rm -rf "$dir"
}

if [[ -n "${FOLIO_SIGN_IDENTITY:-}" ]]; then
    SIGN_ID="$FOLIO_SIGN_IDENTITY"
    SIGN_DESC="from FOLIO_SIGN_IDENTITY"
else
    pick_developer_id
fi

can_notarize() {
    [[ -n "$SIGN_ID" && -n "${ASC_KEY_ID:-}" && -n "${ASC_ISSUER_ID:-}" \
        && -f "${ASC_KEY:-/nonexistent}" ]]
}

notarize() {
    # notarytool exits 0 on a submission that Apple then *rejects*, so the
    # status line is the real verdict — grep it rather than trusting $?.
    local out
    out=$(xcrun notarytool submit "$1" --key "$ASC_KEY" --key-id "$ASC_KEY_ID" \
        --issuer "$ASC_ISSUER_ID" --wait 2>&1) || true
    print -r -- "$out"
    if ! grep -q "status: Accepted" <<< "$out"; then
        print -u2 "!! notarization rejected — inspect with:"
        print -u2 "   xcrun notarytool log <submission-id> --key \"\$ASC_KEY\" \\"
        print -u2 "       --key-id \"\$ASC_KEY_ID\" --issuer \"\$ASC_ISSUER_ID\""
        exit 1
    fi
}

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

if [[ -n "$SIGN_ID" ]]; then
    echo "==> codesign (Developer ID Application — $SIGN_DESC)"
    # --options runtime (hardened runtime) is a hard prerequisite for
    # notarization; --timestamp lets the signature outlive the certificate.
    # No entitlements file: the app is unsandboxed, and WKWebView's JIT runs
    # in Apple's own out-of-process WebContent, not in this binary.
    codesign --force --options runtime --timestamp --sign "$SIGN_ID" "$APP"
else
    echo "==> codesign (ad-hoc — no Developer ID identity in the keychain)"
    codesign --force --sign - "$APP"
fi
codesign --verify --strict --verbose=2 "$APP"

NOTARIZED=0
if can_notarize; then
    echo "==> notarizing $APP_NAME.app"
    ditto -c -k --keepParent "$APP" "$DIST/$APP_NAME.zip"
    notarize "$DIST/$APP_NAME.zip"
    rm -f "$DIST/$APP_NAME.zip"
    # Staple the app itself, not just the .dmg: the stapled ticket is what
    # lets it launch on a machine that is offline or behind a firewall.
    xcrun stapler staple "$APP"
    NOTARIZED=1
elif [[ -n "$SIGN_ID" ]]; then
    echo "==> skipping notarization (no scripts/.env.signing credentials)"
fi

echo "==> registering with Launch Services"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP"

if [[ "${1:-}" == "--dmg" ]]; then
    echo "==> building $DIST/$APP_NAME.dmg"
    rm -f "$DIST/$APP_NAME.dmg"
    STAGING=$(mktemp -d)
    cp -R "$APP" "$STAGING/"
    ln -s /Applications "$STAGING/Applications"

    if (( ! NOTARIZED )); then
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
    fi

    hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING" -ov -format UDZO "$DIST/$APP_NAME.dmg"
    rm -rf "$STAGING"

    if (( NOTARIZED )); then
        # The .dmg is a separate distributable and carries its own quarantine
        # flag when downloaded, so it needs its own ticket — the app's ticket
        # does not cover its container.
        echo "==> notarizing $APP_NAME.dmg"
        notarize "$DIST/$APP_NAME.dmg"
        xcrun stapler staple "$DIST/$APP_NAME.dmg"
    fi
fi

echo "Done: $APP"
if (( NOTARIZED )); then
    spctl -a -vvv -t install "$APP" || true
fi
