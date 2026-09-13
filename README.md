# Xarleta Financas

Aplicativo Flutter de controle financeiro pessoal, com operacao local e suporte
a Android, iOS, Windows, Linux, macOS e Web.

## Recursos

- Lancamentos de ganhos e gastos, contas, parcelamentos e categorias.
- Registro de trabalho, metas e reservas financeiras.
- Dashboard e analises por periodo.
- Tema persistido, PIN, biometria e notificacoes de contas.
- Backup JSON, restauracao transacional e exportacao CSV.

## Inicio rapido

Prerequisitos: Flutter SDK instalado e uma plataforma de destino configurada.

```bash
flutter pub get
flutter test
flutter run
```

Para gerar um APK Android, consulte [COMPILAR_APK_PASSO_A_PASSO.md](COMPILAR_APK_PASSO_A_PASSO.md).

## Documentacao

- [Arquitetura do projeto](PROJECT_ARCHITECTURE.md)
- [Status de desenvolvimento e validacoes pendentes](DEVELOPMENT_STATUS.md)
- [Historico de alteracoes](CHANGELOG.md)

## Dados e seguranca

Os dados financeiros ficam em banco SQLite local e nao devem ser versionados.
O `.gitignore` tambem exclui credenciais, chaves de assinatura e configuracoes
locais. Nunca inclua arquivos de segredo em commits.
