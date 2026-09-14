import 'package:flutter/foundation.dart';

/// Notificador global de mudanças de dados.
///
/// O aplicativo não usa um gerenciador de estado externo: cada tela carrega
/// seus dados em um `Future` próprio (via `FutureBuilder`) e só recarregava
/// quando ela mesma disparava uma ação. Isso fazia com que telas que dependem
/// de dados alterados em outro lugar (por exemplo, o dashboard após criar um
/// lançamento) ficassem desatualizadas até serem reabertas.
///
/// Este notificador centraliza o aviso de "os dados mudaram". Os repositórios
/// disparam [notifyChanged] após cada operação de escrita e as telas escutam
/// para recarregar automaticamente, sem depender de refresh manual.
///
/// É um `ChangeNotifier` simples e síncrono, sem dependências externas, o que
/// mantém a arquitetura atual e evita reconstruções desnecessárias.
class DataChangeNotifier extends ChangeNotifier {
  DataChangeNotifier._();

  static final DataChangeNotifier instance = DataChangeNotifier._();

  /// Contador monotônico de versões. Cada escrita incrementa o valor, o que
  /// permite que consumidores detectem mudanças mesmo sem comparar conteúdo.
  int _version = 0;

  int get version => _version;

  /// Sinaliza que dados persistentes foram alterados (criados, editados,
  /// excluídos ou pagos). Deve ser chamado pelos repositórios após a escrita
  /// ser concluída com sucesso.
  void notifyChanged() {
    _version++;
    notifyListeners();
  }
}
