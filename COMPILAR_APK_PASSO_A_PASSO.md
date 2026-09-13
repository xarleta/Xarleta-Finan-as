# Compilar o Xarleta Finanças no Android

## Opção recomendada: Android Studio + Flutter

1. Instale Flutter SDK.
2. Instale Android Studio.
3. Instale Android SDK e uma plataforma Android.
4. Execute `flutter doctor`.
5. Extraia este projeto.
6. Abra o terminal na pasta do projeto.

Execute:

```bash
flutter pub get
dart format .
flutter analyze
flutter test
flutter run
```

Corrija todos os erros retornados.

Depois:

```bash
flutter build apk --release
```

O APK normalmente será criado em:

`build/app/outputs/flutter-apk/app-release.apk`

## Não pule esta ordem

Não gere APK antes de resolver os erros de `flutter analyze`.
