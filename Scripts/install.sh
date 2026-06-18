 #!/bin/bash
 set -e
 
 SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
 PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
 APP_NAME="MacStats"
 OUTPUT_DIR="$PROJECT_DIR/.build/release"
 APP_BUNDLE="/Applications/$APP_NAME.app"
 
 echo "→ Building $APP_NAME..."
 cd "$PROJECT_DIR"
 swift build -c release
 
 echo "→ Creating .app bundle..."
 mkdir -p "$OUTPUT_DIR/$APP_NAME.app/Contents/MacOS"
 mkdir -p "$OUTPUT_DIR/$APP_NAME.app/Contents/Resources"
 
 cp "$OUTPUT_DIR/$APP_NAME" "$OUTPUT_DIR/$APP_NAME.app/Contents/MacOS/"
 
 cat > "$OUTPUT_DIR/$APP_NAME.app/Contents/Info.plist" << EOF
 <?xml version="1.0" encoding="UTF-8"?>
 <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
 <plist version="1.0">
 <dict>
     <key>CFBundleExecutable</key>
     <string>MacStats</string>
     <key>CFBundleIdentifier</key>
     <string>com.macstats.app</string>
     <key>CFBundleName</key>
     <string>MacStats</string>
     <key>CFBundleVersion</key>
     <string>1.0</string>
     <key>CFBundleShortVersionString</key>
     <string>1.0</string>
     <key>CFBundlePackageType</key>
     <string>APPL</string>
     <key>LSUIElement</key>
     <true/>
     <key>NSHighResolutionCapable</key>
     <true/>
 </dict>
 </plist>
 EOF
 
 echo "→ Installing to /Applications..."
 if [ -d "$APP_BUNDLE" ]; then
     rm -rf "$APP_BUNDLE"
 fi
 cp -R "$OUTPUT_DIR/$APP_NAME.app" "$APP_BUNDLE"
 
 echo "✅ Done! App installed to: $APP_BUNDLE"
 echo ""
 echo "启动方式:"
 echo "  方法 1: 在 Finder 中双击 /Applications/MacStats.app"
 echo "  方法 2: 终端运行: open /Applications/MacStats.app"
 echo ""
 echo "启动后可在菜单栏找到 CPU 图标，点击即可查看所有系统状态。"
 echo "点击菜单中的「桌面组件」按钮可显示浮动窗口。"
