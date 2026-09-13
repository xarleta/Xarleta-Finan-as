import 'package:flutter/material.dart';

import 'data/dashboard_preferences_repository.dart';

/// Tela de personalização do dashboard.
///
/// Permite mostrar/ocultar os widgets reais do dashboard, reordená-los e
/// restaurar a configuração padrão. A configuração é persistida na tabela
/// `app_settings` e devolvida ao dashboard via `Navigator.pop(context, true)`
/// quando há alteração, para que a tela inicial recarregue.
class DashboardCustomizePage extends StatefulWidget {
  const DashboardCustomizePage({super.key});

  @override
  State<DashboardCustomizePage> createState() => _DashboardCustomizePageState();
}

class _DashboardCustomizePageState extends State<DashboardCustomizePage> {
  bool _loading = true;
  Object? _error;
  DashboardPreferences _preferences = DashboardPreferences.defaults;

  /// Indica se houve alguma alteração salva (para sinalizar o dashboard).
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final preferences = await DashboardPreferencesRepository.instance.load();
      if (!mounted) return;
      setState(() {
        _preferences = preferences;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _persist(DashboardPreferences next) async {
    // Atualiza a UI imediatamente (resposta instantânea) e persiste em seguida.
    setState(() {
      _preferences = next;
      _changed = true;
    });

    try {
      await DashboardPreferencesRepository.instance.save(next);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não foi possível salvar a configuração: $e'),
        ),
      );
    }
  }

  Future<void> _toggle(DashboardWidget widget, bool visible) async {
    final hidden = Set<DashboardWidget>.from(_preferences.hidden);
    if (visible) {
      hidden.remove(widget);
    } else {
      hidden.add(widget);
    }
    await _persist(_preferences.copyWith(hidden: hidden));
  }

  Future<void> _move(int index, int delta) async {
    final target = index + delta;
    final order = List<DashboardWidget>.from(_preferences.order);
    if (target < 0 || target >= order.length) return;

    final item = order.removeAt(index);
    order.insert(target, item);

    await _persist(_preferences.copyWith(order: order));
  }

  Future<void> _restoreDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restaurar padrão?'),
        content: const Text(
          'A ordem e a visibilidade dos cards voltarão ao padrão original.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('CANCELAR'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('RESTAURAR'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await DashboardPreferencesRepository.instance.reset();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível restaurar o padrão: $e')),
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _preferences = DashboardPreferences.defaults;
      _changed = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Configuração padrão restaurada.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // Devolve `true` quando houve alteração para o dashboard recarregar.
        Navigator.pop(context, _changed);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Personalizar dashboard')),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              const Text(
                'Não foi possível carregar a personalização.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _load,
                child: const Text('TENTAR NOVAMENTE'),
              ),
            ],
          ),
        ),
      );
    }

    final order = _preferences.order;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Mostrar ou ocultar cards',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Use as setas para reordenar. A ordem abaixo é a ordem exibida no Início.',
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < order.length; i++)
          _WidgetTile(
            widget: order[i],
            visible: _preferences.isVisible(order[i]),
            canMoveUp: i > 0,
            canMoveDown: i < order.length - 1,
            onVisibilityChanged: (value) => _toggle(order[i], value),
            onMoveUp: () => _move(i, -1),
            onMoveDown: () => _move(i, 1),
          ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: _restoreDefaults,
          icon: const Icon(Icons.restore),
          label: const Text('RESTAURAR PADRÃO'),
        ),
      ],
    );
  }
}

class _WidgetTile extends StatelessWidget {
  final DashboardWidget widget;
  final bool visible;
  final bool canMoveUp;
  final bool canMoveDown;
  final ValueChanged<bool> onVisibilityChanged;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  const _WidgetTile({
    required this.widget,
    required this.visible,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onVisibilityChanged,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(widget.label),
        leading: Switch(
          value: visible,
          onChanged: onVisibilityChanged,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Mover para cima',
              onPressed: canMoveUp ? onMoveUp : null,
              icon: const Icon(Icons.arrow_upward),
            ),
            IconButton(
              tooltip: 'Mover para baixo',
              onPressed: canMoveDown ? onMoveDown : null,
              icon: const Icon(Icons.arrow_downward),
            ),
          ],
        ),
      ),
    );
  }
}
