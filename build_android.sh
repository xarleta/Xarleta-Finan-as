#!/usr/bin/env bash
set -e

flutter pub get
dart format .
flutter analyze
flutter test
flutter build apk --release

echo "APK gerado com sucesso."
