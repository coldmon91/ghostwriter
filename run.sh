#!/usr/bin/env bash
# Build and run Ghostwriter.
# Usage: ./run.sh [--release] [--build-only] [--clean]

set -euo pipefail

cd "$(dirname "$0")"

PROJECT="Ghostwriter.xcodeproj"
SCHEME="Ghostwriter"
CONFIG="Debug"
BUILD_ONLY=false
CLEAN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --release)    CONFIG="Release"; shift ;;
        --build-only) BUILD_ONLY=true; shift ;;
        --clean)      CLEAN=true; shift ;;
        -h|--help)
            cat <<EOF
Usage: $0 [options]
  --release      Build in Release configuration (default: Debug)
  --build-only   Build without launching the app
  --clean        Clean before building
  -h, --help     Show this help
EOF
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Run '$0 --help' for usage." >&2
            exit 1
            ;;
    esac
done

if ! command -v xcodegen >/dev/null 2>&1; then
    echo "Error: xcodegen not installed. Run 'brew install xcodegen'." >&2
    exit 1
fi

if [ ! -d "$PROJECT" ] || [ "project.yml" -nt "$PROJECT/project.pbxproj" ]; then
    echo "==> Generating Xcode project"
    xcodegen generate
fi

if pgrep -x "Ghostwriter" >/dev/null 2>&1; then
    echo "==> Stopping running Ghostwriter"
    pkill -x "Ghostwriter" || true
    sleep 1
fi

LOG=$(mktemp -t ghostwriter-build.XXXXXX)
trap 'rm -f "$LOG"' EXIT

XCB_ARGS=(-project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIG" -destination "platform=macOS")

if [ "$CLEAN" = true ]; then
    echo "==> Cleaning"
    xcodebuild "${XCB_ARGS[@]}" clean > "$LOG" 2>&1 || {
        tail -30 "$LOG"
        exit 1
    }
fi

echo "==> Building ($CONFIG)"
if ! xcodebuild "${XCB_ARGS[@]}" build > "$LOG" 2>&1; then
    echo "==> BUILD FAILED"
    grep -E "error:|warning:" "$LOG" | head -50 || true
    echo
    echo "--- last 50 lines ---"
    tail -50 "$LOG"
    exit 1
fi
echo "==> Build succeeded"

if [ "$BUILD_ONLY" = true ]; then
    exit 0
fi

APP=$(find "$HOME/Library/Developer/Xcode/DerivedData/" \
    -maxdepth 5 -type d -name "Ghostwriter.app" \
    -path "*/Build/Products/$CONFIG/*" 2>/dev/null | head -1)

if [ -z "$APP" ]; then
    echo "Error: built Ghostwriter.app not found in DerivedData." >&2
    exit 1
fi

echo "==> Launching $APP"
open "$APP"
