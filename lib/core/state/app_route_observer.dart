import 'package:flutter/widgets.dart';

/// Observador global de rotas usado pelo [DataChangeListenerMixin].
///
/// Permite que uma tela saiba quando volta a ser a rota visível (por exemplo,
/// após o fechamento de um `showDialog` ou o retorno de uma tela empilhada).
/// Isso é necessário porque, durante um diálogo, a rota da tela deixa de ser a
/// atual; se uma escrita no banco acontecer nesse intervalo, a recarga precisa
/// ser aplicada assim que a tela voltar a ficar visível — caso contrário a
/// notificação ficaria pendente e a interface permaneceria desatualizada.
final RouteObserver<ModalRoute<void>> appRouteObserver =
    RouteObserver<ModalRoute<void>>();
