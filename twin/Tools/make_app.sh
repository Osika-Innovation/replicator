#!/bin/sh
# Assemble "Field Compiler.app" from the SwiftPM build — a real macOS app
# (Dock name, double-clickable, addressable by bundle id) around the same
# binary `swift run FieldCompilerApp` runs. Unsigned, for local use.
#   Tools/make_app.sh            → .build/Field Compiler.app
#   open ".build/Field Compiler.app" --args --machine
set -e
cd "$(dirname "$0")/.."
swift build -c release --product FieldCompilerApp
BIN=".build/release"
APP=".build/Field Compiler.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/FieldCompilerApp" "$APP/Contents/MacOS/FieldCompilerApp"
# SwiftPM's resource accessor looks next to Bundle.main.bundleURL first.
for b in "$BIN"/*.bundle; do cp -R "$b" "$APP/"; done
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>Field Compiler</string>
  <key>CFBundleDisplayName</key><string>Field Compiler</string>
  <key>CFBundleIdentifier</key><string>com.osikainnovation.fieldcompiler</string>
  <key>CFBundleExecutable</key><string>FieldCompilerApp</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.9</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
echo "built $APP"
