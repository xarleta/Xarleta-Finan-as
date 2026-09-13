# Configuração Android

Adicionar ao `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.USE_BIOMETRIC"/>
<uses-permission android:name="android.permission.USE_FINGERPRINT"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
```

Para notificações agendadas persistentes após reinicialização do aparelho, configurar também os receivers exigidos pela versão instalada de flutter_local_notifications.

Antes de gerar APK:
1. flutter pub get
2. flutter analyze
3. flutter test
4. flutter build apk --release
