# Preparação do APK — V9

## Dependências adicionadas
- file_picker

## Fluxo obrigatório no computador com Flutter

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Depois dos testes:

```bash
flutter build apk --release
```

## Antes do APK

Verificar:
- AndroidManifest
- minSdk compatível com local_auth e notificações
- permissões
- ícone do app
- applicationId
- nome Xarleta Finanças

## Resultado esperado

APK release instalável diretamente no Android.

## Honestidade técnica

Este pacote prepara o projeto para compilação.
O APK ainda precisa ser gerado em uma máquina com Flutter SDK.
