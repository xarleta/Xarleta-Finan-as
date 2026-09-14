import 'package:flutter/widgets.dart';

import 'data_change_notifier.dart';

/// Mixin para telas que devem recarregar automaticamente quando dados
/// persistentes mudarem em qualquer parte do aplicativo.
///
/// Uso:
/// ```dart
/// class _MinhaTelaState extends State<MinhaTela>
///     with DataChangeListenerMixin {
///   @override
///   void onDataChanged() {
///     // recarregar os dados desta tela
///   }
/// }
/// ```
///
/// O mixin registra o listener no [DataChangeNotifier] em [initState] e o
/// remove em [dispose], evitando vazamentos. A recarga só ocorre quando a tela
/// está montada, e [onDataChanged] é chamado fora do ciclo de build para não
/// disparar `setState` durante a construção.
mixin DataChangeListenerMixin<T extends StatefulWidget> on State<T> {
  @override
  void initState() {
    super.initState();
    DataChangeNotifier.instance.addListener(_handleDataChange);
  }

  @override
  void dispose() {
    DataChangeNotifier.instance.removeListener(_handleDataChange);
    super.dispose();
  }

  void _handleDataChange() {
    if (!mounted) return;
    onDataChanged();
  }

  /// Chamado quando dados persistentes mudam. Implemente para recarregar os
  /// dados exibidos por esta tela.
  void onDataChanged();
}
