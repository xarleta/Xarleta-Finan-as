package com.example.xarleta_financas

import io.flutter.embedding.android.FlutterFragmentActivity

// O plugin local_auth (BiometricPrompt) exige uma FragmentActivity para
// hospedar o diálogo nativo de biometria. Com FlutterActivity o prompt nunca
// é exibido e a chamada falha silenciosamente.
class MainActivity : FlutterFragmentActivity()
