#!/bin/bash
# Runs flutter test inside the Linux container so goldens match CI.

set -e

PACKAGE_PATH="/project"
TEST_PATH=""
UPDATE_GOLDENS=""
COVERAGE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --packagePath)
      PACKAGE_PATH="$2"
      shift 2
      ;;
    --update-goldens)
      UPDATE_GOLDENS="--update-goldens"
      shift
      ;;
    --coverage)
      COVERAGE="--coverage"
      shift
      ;;
    test/*.dart)
      TEST_PATH="$1"
      shift
      ;;
    *)
      shift
      ;;
  esac
done

cd "$PACKAGE_PATH"

echo "🧪 Test path: ${TEST_PATH:-all tests} | 🎨 Update goldens: ${UPDATE_GOLDENS:-no} | 📊 Coverage: ${COVERAGE:-no}"

flutter pub get
flutter test ${TEST_PATH:+"$TEST_PATH"} $UPDATE_GOLDENS $COVERAGE

echo "✅ Tests completed successfully!"
