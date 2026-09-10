/// Configuração de um leitor de registro (armada, concretada, montagem).
class LeitorRegistrarConfig {
  const LeitorRegistrarConfig({
    required this.titulo,
    required this.subtitulo,
    required this.statusAlvo,
    required this.campoData,
    required this.acaoLabel,
    required this.chaveLast,
    required this.chaveHistory,
  });

  final String titulo;
  final String subtitulo;
  final String statusAlvo;
  final String campoData;

  /// Rótulo da ação no particípio (ex.: "armada", "concretada", "montada").
  final String acaoLabel;
  final String chaveLast;
  final String chaveHistory;
}

const leitorArmadaConfig = LeitorRegistrarConfig(
  titulo: 'Registrar Peça Armada',
  subtitulo: 'Escaneie o QR Code para marcar a peça como armada',
  statusAlvo: 'armada',
  campoData: 'data_armacao',
  acaoLabel: 'armada',
  chaveLast: 'leitor_armada_last',
  chaveHistory: 'leitor_armada_history',
);

const leitorConcretadaConfig = LeitorRegistrarConfig(
  titulo: 'Registrar Peça Concretada',
  subtitulo: 'Escaneie o QR Code para marcar a peça como concretada',
  statusAlvo: 'concretada',
  campoData: 'data_concretagem',
  acaoLabel: 'concretada',
  chaveLast: 'leitor_concretada_last',
  chaveHistory: 'leitor_concretada_history',
);

const leitorMontagemConfig = LeitorRegistrarConfig(
  titulo: 'Registrar Peça Montada',
  subtitulo: 'Escaneie o QR Code para marcar a peça como montada',
  statusAlvo: 'montada',
  campoData: 'data_montagem',
  acaoLabel: 'montada',
  chaveLast: 'leitor_montagem_last',
  chaveHistory: 'leitor_montagem_history',
);
