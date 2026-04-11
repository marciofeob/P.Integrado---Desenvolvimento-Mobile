import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/database_helper.dart';
import '../widgets/widgets.dart';

/// Tela de consulta do log de atividades do sistema.
///
/// Exibe todos os eventos registrados pelo STOX com indicadores visuais:
/// - 🟢 Sucesso (verde) — operações concluídas com êxito
/// - 🔵 Info (azul) — eventos informativos (login, início de operação)
/// - 🟡 Aviso (amarelo) — situações que merecem atenção
/// - 🔴 Erro (vermelho) — falhas com detalhes técnicos
///
/// Funcionalidades:
/// - Filtro por nível (Todos / Sucesso / Info / Aviso / Erro)
/// - Filtro por categoria (Sync / Auth / Import / Sistema)
/// - Contadores resumidos no topo
/// - Expandir para ver detalhes técnicos (tap no card de erro)
/// - Copiar detalhes técnicos para a área de transferência
///
/// Política de retenção:
/// - Logs são podados automaticamente após 90 dias
/// - O usuário não pode apagar logs pelo app
/// - Para limpar, usar "Limpar dados" nas configurações do Android
class LogPage extends StatefulWidget {
  const LogPage({super.key});

  @override
  State<LogPage> createState() => _LogPageState();
}

class _LogPageState extends State<LogPage> {
  List<Map<String, dynamic>> _logs = [];
  Map<String, int> _contadores = {};
  bool _carregando = true;

  String? _filtroNivel;
  String? _filtroCategoria;

  @override
  void initState() {
    super.initState();
    _carregarLogs();
  }

  // ── Dados ─────────────────────────────────────────────────────────────────

  Future<void> _carregarLogs() async {
    setState(() => _carregando = true);

    final resultados = await Future.wait([
      DatabaseHelper.instance.buscarLogs(
        nivel: _filtroNivel,
        categoria: _filtroCategoria,
      ),
      DatabaseHelper.instance.contarLogsPorNivel(),
    ]);

    if (!mounted) return;
    setState(() {
      _logs = resultados[0] as List<Map<String, dynamic>>;
      _contadores = resultados[1] as Map<String, int>;
      _carregando = false;
    });
  }

  void _aplicarFiltroNivel(String? nivel) {
    HapticFeedback.selectionClick();
    setState(() => _filtroNivel = _filtroNivel == nivel ? null : nivel);
    _carregarLogs();
  }

  void _aplicarFiltroCategoria(String? categoria) {
    HapticFeedback.selectionClick();
    setState(() =>
        _filtroCategoria = _filtroCategoria == categoria ? null : categoria);
    _carregarLogs();
  }

  // ── Helpers visuais ───────────────────────────────────────────────────────

  static Color _corNivel(String nivel) => switch (nivel) {
        'sucesso' => Colors.green.shade600,
        'info' => Colors.blue.shade600,
        'aviso' => Colors.orange.shade700,
        'erro' => Colors.red.shade600,
        _ => Colors.grey.shade500,
      };

  static IconData _iconeNivel(String nivel) => switch (nivel) {
        'sucesso' => Icons.check_circle_rounded,
        'info' => Icons.info_rounded,
        'aviso' => Icons.warning_amber_rounded,
        'erro' => Icons.error_rounded,
        _ => Icons.circle,
      };

  static String _labelNivel(String nivel) => switch (nivel) {
        'sucesso' => 'Sucesso',
        'info' => 'Info',
        'aviso' => 'Aviso',
        'erro' => 'Erro',
        _ => nivel,
      };

  static IconData _iconeCategoria(String categoria) => switch (categoria) {
        'sync' => Icons.sync_rounded,
        'auth' => Icons.lock_rounded,
        'import' => Icons.upload_file_rounded,
        'sistema' => Icons.settings_rounded,
        _ => Icons.label_rounded,
      };

  static String _labelCategoria(String categoria) => switch (categoria) {
        'sync' => 'Sincronização',
        'auth' => 'Autenticação',
        'import' => 'Importação',
        'sistema' => 'Sistema',
        _ => categoria,
      };

  static String _formatarData(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/'
          '${dt.year} '
          '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}:'
          '${dt.second.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final totalLogs = _contadores.values.fold(0, (a, b) => a + b);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Log do Sistema'),
        actions: [
          if (_filtroNivel != null || _filtroCategoria != null)
            IconButton(
              icon: const Icon(Icons.filter_alt_off_rounded),
              tooltip: 'Limpar filtros',
              onPressed: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _filtroNivel = null;
                  _filtroCategoria = null;
                });
                _carregarLogs();
              },
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Atualizar',
            onPressed: () {
              HapticFeedback.lightImpact();
              _carregarLogs();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_carregando) const StoxLinearLoading(),

            // ── Contadores resumidos ──
            _buildContadores(totalLogs),

            // ── Filtros por categoria ──
            _buildFiltrosCategorias(),

            // ── Lista de logs ──
            Expanded(
              child: _carregando && _logs.isEmpty
                  ? const StoxSkeletonList(quantidade: 6)
                  : _logs.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: _logs.length,
                          itemBuilder: (_, i) => _buildItemLog(_logs[i]),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Contadores ────────────────────────────────────────────────────────────

  Widget _buildContadores(int total) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          _buildChipContador(
            'Todos',
            total,
            null,
            Colors.grey.shade600,
          ),
          const SizedBox(width: 6),
          _buildChipContador(
            'Sucesso',
            _contadores['sucesso'] ?? 0,
            'sucesso',
            Colors.green.shade600,
          ),
          const SizedBox(width: 6),
          _buildChipContador(
            'Aviso',
            _contadores['aviso'] ?? 0,
            'aviso',
            Colors.orange.shade700,
          ),
          const SizedBox(width: 6),
          _buildChipContador(
            'Erro',
            _contadores['erro'] ?? 0,
            'erro',
            Colors.red.shade600,
          ),
        ],
      ),
    );
  }

  Widget _buildChipContador(
    String label,
    int count,
    String? nivel,
    Color cor,
  ) {
    final ativo = _filtroNivel == nivel;
    return Expanded(
      child: GestureDetector(
        onTap: () => _aplicarFiltroNivel(nivel),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: ativo ? cor.withAlpha(20) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: ativo ? cor : Colors.grey.shade200,
              width: ativo ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                '$count',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: ativo ? cor : Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: ativo ? FontWeight.w700 : FontWeight.w500,
                  color: ativo ? cor : Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Filtros de categoria ──────────────────────────────────────────────────

  Widget _buildFiltrosCategorias() {
    const categorias = ['sync', 'auth', 'import', 'sistema'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: categorias.map((cat) {
          final ativo = _filtroCategoria == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _iconeCategoria(cat),
                    size: 14,
                    color: ativo ? Colors.white : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(_labelCategoria(cat)),
                ],
              ),
              selected: ativo,
              onSelected: (_) => _aplicarFiltroCategoria(cat),
              selectedColor: Theme.of(context).primaryColor,
              backgroundColor: Colors.grey.shade50,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: ativo ? Colors.white : Colors.grey.shade700,
              ),
              checkmarkColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: ativo
                      ? Theme.of(context).primaryColor
                      : Colors.grey.shade300,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              visualDensity: VisualDensity.compact,
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Item do log ───────────────────────────────────────────────────────────

  Widget _buildItemLog(Map<String, dynamic> log) {
    final nivel = log['nivel'] as String? ?? 'info';
    final categoria = log['categoria'] as String? ?? 'sistema';
    final titulo = log['titulo'] as String? ?? '';
    final mensagem = log['mensagem'] as String?;
    final detalhes = log['detalhes'] as String?;
    final dataHora = log['dataHora'] as String? ?? '';

    final cor = _corNivel(nivel);
    final temDetalhes = detalhes != null && detalhes.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: StoxCard(
        borderColor: cor.withAlpha(50),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 14),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: cor.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: Icon(_iconeNivel(nivel), color: cor, size: 20),
            ),
            title: Text(
              titulo,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  // ── Badge de nível ──
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: cor.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _labelNivel(nivel),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: cor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // ── Badge de categoria ──
                  Icon(_iconeCategoria(categoria),
                      size: 11, color: Colors.grey.shade500),
                  const SizedBox(width: 3),
                  Text(
                    _labelCategoria(categoria),
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade500,
                    ),
                  ),

                  const Spacer(),

                  // ── Data/hora ──
                  Text(
                    _formatarData(dataHora),
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),
            trailing: temDetalhes
                ? Icon(Icons.expand_more_rounded,
                    size: 20, color: Colors.grey.shade400)
                : const SizedBox(width: 20),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Mensagem ──
              if (mensagem != null && mensagem.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  mensagem,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                    height: 1.5,
                  ),
                ),
              ],

              // ── Detalhes técnicos ──
              if (temDetalhes) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Detalhes técnicos',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(
                                ClipboardData(text: detalhes),
                              );
                              HapticFeedback.selectionClick();
                              StoxSnackbar.sucesso(
                                context,
                                'Detalhes copiados.',
                              );
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.copy_rounded,
                                    size: 12, color: Colors.grey.shade500),
                                const SizedBox(width: 4),
                                Text(
                                  'Copiar',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade500,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SelectableText(
                        detalhes,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          color: Colors.blueGrey.shade700,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    final temFiltro = _filtroNivel != null || _filtroCategoria != null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              temFiltro
                  ? Icons.filter_list_off_rounded
                  : Icons.receipt_long_rounded,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              temFiltro
                  ? 'Nenhum registro com este filtro'
                  : 'Nenhum registro de atividade',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              temFiltro
                  ? 'Tente remover os filtros para ver todos os eventos.'
                  : 'Os eventos de sincronização, login e importação\n'
                      'serão registrados aqui automaticamente.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade400,
                height: 1.5,
              ),
            ),
            if (temFiltro) ...[
              const SizedBox(height: 20),
              StoxOutlinedButton(
                label: 'LIMPAR FILTROS',
                icon: Icons.filter_alt_off_rounded,
                onPressed: () {
                  setState(() {
                    _filtroNivel = null;
                    _filtroCategoria = null;
                  });
                  _carregarLogs();
                },
                height: 44,
              ),
            ],
          ],
        ),
      ),
    );
  }
}