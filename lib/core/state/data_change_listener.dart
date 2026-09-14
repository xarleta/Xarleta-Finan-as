import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'app_route_observer.dart';
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
///
/// ## Coalescência sem perda de notificações
///
/// Uma única escrita pode disparar várias notificações (ex.: pagar uma conta
/// gera transação + atualiza a conta + cria a próxima ocorrência). Sem
/// controle, cada tela montada recarregaria a cada notificação, multiplicando
/// consultas ao banco.
///
/// A coalescência aqui **não descarta** notificações: se uma notificação
/// chegar enquanto uma recarga já está agendada, ela apenas marca que há
/// trabalho pendente (`_pending`) e a recarga agendada é reaproveitada. Isso
/// garante que o estado final exibido sempre reflita a última escrita, sem
/// perder a atualização — o problema anterior era justamente descartar a
/// notificação e deixar a tela desatualizada.
///
/// ## Visibilidade da rota
///
/// A recarga é adiada para fora do ciclo de build. Telas que não são a rota
/// atual (empilhadas atrás de outra) não recarregam imediatamente. A
/// verificação é feita no momento da execução (e não no momento da
/// notificação), pois durante um `showDialog` a rota da tela deixa de ser a
/// atual temporariamente — verificar cedo demais descartaria a notificação.
///
/// Quando a recarga é adiada por a tela não estar visível, a pendência é
/// registrada e aplicada assim que a tela volta a ser a rota atual (via
/// [RouteAware.didPopNext], alimentado pelo [appRouteObserver]). Sem isso, uma
/// escrita feita enquanto um diálogo estava aberto (ex.: confirmar o pagamento)
/// ficaria pendente para sempre e a interface permaneceria desatualizada.
mixin DataChangeListenerMixin<T extends StatefulWidget> on State<T>
    implements RouteAware {
  /// `true` enquanto existe uma recarga agendada para o próximo frame/microtask.
  bool _reloadScheduled = false;

  /// `true` quando uma notificação chegou enquanto uma recarga já estava
  /// agendada. Nesse caso a recarga agendada é reaproveitada (coalescência),
  /// mas a flag garante que o estado final seja relido.
  bool _pending = false;

  /// `true` quando a recarga foi adiada porque a tela não era a rota atual.
  /// Ao voltar a ser visível, essa pendência é aplicada.
  bool _reloadDeferred = false;

  /// Rota à qual este State está inscrito no [appRouteObserver].
  ModalRoute<void>? _subscribedRoute;

  @override
  void initState() {
    super.initState();
    DataChangeNotifier.instance.addListener(_handleDataChange);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // (Re)inscreve a rota atual no observador. `didChangeDependencies` é
    // chamado quando a rota associada muda, permitindo manter a inscrição
    // correta mesmo quando a tela é reutilizada em outra rota.
    final route = ModalRoute.of(context);
    if (route != _subscribedRoute) {
      if (_subscribedRoute != null) {
        appRouteObserver.unsubscribe(this);
      }
      _subscribedRoute = route;
      if (route != null) {
        appRouteObserver.subscribe(this, route);
      }
    }
  }

  @override
  void dispose() {
    DataChangeNotifier.instance.removeListener(_handleDataChange);
    if (_subscribedRoute != null) {
      appRouteObserver.unsubscribe(this);
      _subscribedRoute = null;
    }
    super.dispose();
  }

  /// Chamado quando a rota desta tela volta a ser a atual (ex.: após fechar um
  /// diálogo ou retornar de uma tela empilhada). Aplica a recarga que ficou
  /// pendente enquanto a tela estava coberta.
  @override
  void didPopNext() {
    if (!mounted) return;
    if (_reloadDeferred || _pending) {
      _reloadDeferred = false;
      _pending = false;
      _runReload();
    }
  }

  // Os demais callbacks de [RouteAware] não são necessários para a recarga
  // automática; implementações vazias evitam obrigar cada tela a declará-los.
  @override
  void didPop() {}

  @override
  void didPush() {}

  @override
  void didPushNext() {}

  void _handleDataChange() {
    if (!mounted) return;

    // Já existe uma recarga agendada: apenas registra que há trabalho pendente.
    // A recarga agendada relerá o estado mais recente do banco, então não é
    // necessário agendar outra — mas a notificação NÃO é descartada.
    if (_reloadScheduled) {
      _pending = true;
      return;
    }

    _reloadScheduled = true;
    _pending = false;

    // A recarga precisa ocorrer fora do ciclo de build (para não chamar
    // `setState` durante a construção). O comportamento depende da fase atual
    // do scheduler:
    //
    // - Se estamos no meio de um build/layout (`persistentCallbacks`), a
    //   recarga é adiada para o fim do frame via `addPostFrameCallback`.
    // - Caso contrário (fase `idle` ou `postFrameCallbacks`, típico de uma
    //   notificação disparada após um `await` de escrita no banco), não há
    //   frame em andamento: agendar apenas um post-frame callback deixaria a
    //   flag `_reloadScheduled` presa em `true` até que algum outro evento
    //   provocasse um frame — deixando a tela desatualizada. Nesse caso a
    //   recarga é executada em um microtask, imediatamente após o término da
    //   notificação atual.
    final phase = SchedulerBinding.instance.schedulerPhase;
    final inBuildPhase = phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks;

    if (inBuildPhase) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _runReload());
    } else {
      scheduleMicrotask(_runReload);
    }
  }

  void _runReload() {
    _reloadScheduled = false;

    if (!mounted) return;

    // A verificação de visibilidade é feita aqui (e não no momento da
    // notificação): durante um `showDialog` a rota da tela deixa de ser a
    // atual, mas a notificação ainda precisa ser aplicada. Se a tela não for
    // a rota atual, a recarga é adiada e será aplicada em `didPopNext()`
    // quando a tela voltar a ser visível.
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) {
      _reloadDeferred = true;
      return;
    }

    _reloadDeferred = false;

    // As notificações que chegaram ANTES desta recarga já estão contempladas:
    // a recarga lê o estado mais recente do banco. Zerar `_pending` aqui faz
    // com que apenas notificações que chegarem DURANTE `onDataChanged()`
    // (isto é, uma escrita disparada pela própria recarga) provoquem uma nova
    // passada — evitando recargas duplicadas desnecessárias.
    _pending = false;

    onDataChanged();

    // Se novas notificações chegaram durante a recarga, agenda outra para
    // garantir que o estado final seja relido.
    if (_pending) {
      _pending = false;
      _handleDataChange();
    }
  }

  /// Chamado quando dados persistentes mudam. Implemente para recarregar os
  /// dados exibidos por esta tela.
  void onDataChanged();
}
