 #!/bin/bash
 
 SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
 PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
 
 echo "→ Building MacStats..."
 cd "$PROJECT_DIR"
 swift build -c release
 
 echo "→ Launching MacStats (background, no Dock icon)..."
 # Run in background so the terminal stays usable
 nohup .build/release/MacStats > /dev/null 2>&1 &
 
 echo "✅ MacStats started! Look for the CPU icon in your menu bar."
 echo ""
 echo "停止方式: killall MacStats"
