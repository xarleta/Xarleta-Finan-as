import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';

/// Identificador de cada widget real do dashboard.
///
/// Apenas widgets que existem de fato na tela são listados aqui. Não há
/// opções fictícias: se um widget não é renderizado pelo dashboard, ele não
/// aparece nesta enumeração.
enum DashboardWidget {
  /// Card principal com o saldo disponível.
  balance('balance', 'Saldo disponível'),

  /// Card com o total de entradas.
  income('income', 'Entradas'),

  /// Card com o total de saídas.
  expense('expense', 'Saídas'),

  /// Card de dica ("Controle rápido").
  tip('tip', 'Dica');

  const DashboardWidget(this.id, this.label);

  /// Chave estável usada na persistência (não depende do nome do enum).
  final String id;

  /// Rótulo exibido ao usuário.
  final String label;

  /// Converte uma chave persistida de volta para o enum, ou `null` se
  /// desconhecida (permite ignorar entradas antigas/inválidas com segurança).
  static DashboardWidget? fromId(String id) {
    for (final widget in DashboardWidget.values) {
      if (widget.id == id) return widget;
    }
    return null;
  }
}

/// Configuração de personalização do dashboard.
///
/// Mantém a ordem dos widgets e quais estão visíveis. É imutável para evitar
/// alterações acidentais de estado compartilhado.
class DashboardPreferences {
  const DashboardPreferences({
    required this.order,
    required this.hidden,
  });

  /// Ordem de exibição dos widgets.
  final List<DashboardWidget> order;

  /// Conjunto de widgets ocultos.
  final Set<DashboardWidget> hidden;

  /// Configuração padrão: todos os widgets visíveis na ordem original.
  static DashboardPreferences get defaults => DashboardPreferences(
    order: List<DashboardWidget>.unmodifiable(DashboardWidget.values),
    hidden: const <DashboardWidget>{},
  );

  /// Indica se um widget deve ser exibido.
  bool isVisible(DashboardWidget widget) => !hidden.contains(widget);

  /// Retorna apenas os widgets visíveis, respeitando a ordem configurada.
  List<DashboardWidget> get visibleOrder =>
      order.where(isVisible).toList(growable: false);

  DashboardPreferences copyWith({
    List<DashboardWidget>? order,
    Set<DashboardWidget>? hidden,
  }) {
    return DashboardPreferences(
      order: order ?? this.order,
      hidden: hidden ?? this.hidden,
    );
  }

  Map<String, dynamic> toJson() => {
    'order': order.map((w) => w.id).toList(),
    'hidden': hidden.map((w) => w.id).toList(),
  };

  /// Reconstrói a configuração a partir do JSON persistido.
  ///
  /// Tolerante a dados inválidos: widgets desconhecidos são ignorados e
  /// widgets ausentes são acrescentados ao final, garantindo que a ordem
  /// sempre contenha todos os widgets exatamente uma vez.
  static DashboardPreferences fromJson(Map<String, dynamic> json) {
    final rawOrder = json['order'];
    final rawHidden = json['hidden'];

    final order = <DashboardWidget>[];
    if (rawOrder is List) {
      for (final item in rawOrder) {
        if (item is! String) continue;
        final widget = DashboardWidget.fromId(item);
        if (widget != null && !order.contains(widget)) {
          order.add(widget);
        }
      }
    }

    // Acrescenta widgets ausentes preservando a ordem padrão.
    for (final widget in DashboardWidget.values) {
      if (!order.contains(widget)) order.add(widget);
    }

    final hidden = <DashboardWidget>{};
    if (rawHidden is List) {
      for (final item in rawHidden) {
        if (item is! String) continue;
        final widget = DashboardWidget.fromId(item);
        if (widget != null) hidden.add(widget);
      }
    }

    return DashboardPreferences(
      order: List<DashboardWidget>.unmodifiable(order),
      hidden: Set<DashboardWidget>.unmodifiable(hidden),
    );
  }
}

/// Persiste a personalização do dashboard na tabela `app_settings`, que já
/// existe no banco desde a versão 7 e é incluída nos backups.
class DashboardPreferencesRepository {
  DashboardPreferencesRepository._();

  static final instance = DashboardPreferencesRepository._();

  /// Chave usada na tabela `app_settings`.
  static const String _key = 'dashboard_preferences';

  /// Lê a configuração salva. Em caso de ausência, dado inválido ou falha de
  /// leitura, retorna a configuração padrão (nunca lança para a UI).
  Future<DashboardPreferences> load() async {
    try {
      final db = await AppDatabase.instance.database;
      final rows = await db.query(
        'app_settings',
        where: 'key = ?',
        whereArgs: [_key],
        limit: 1,
      );

      if (rows.isEmpty) return DashboardPreferences.defaults;

      final raw = rows.first['value'];
      if (raw is! String || raw.isEmpty) {
        return DashboardPreferences.defaults;
      }

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return DashboardPreferences.defaults;
      }

      return DashboardPreferences.fromJson(decoded);
    } catch (_) {
      // Falha ao ler a preferência não pode impedir o dashboard de carregar.
      return DashboardPreferences.defaults;
    }
  }

  /// Salva a configuração. Usa `ConflictAlgorithm.replace` porque a chave é
  /// primária, garantindo atualização idempotente.
  Future<void> save(DashboardPreferences preferences) async {
    final db = await AppDatabase.instance.database;
    await db.insert(
      'app_settings',
      {
        'key': _key,
        'value': jsonEncode(preferences.toJson()),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Restaura a configuração padrão, removendo a preferência salva.
  Future<void> reset() async {
    final db = await AppDatabase.instance.database;
    await db.delete('app_settings', where: 'key = ?', whereArgs: [_key]);
  }
}
