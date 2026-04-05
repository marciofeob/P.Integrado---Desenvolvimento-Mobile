import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/stox_audio.dart';

/// Página de scanner de código de barras com área de leitura restrita.
///
/// Implementa:
/// - Viewfinder retangular com área de leitura delimitada (evita capturar
///   códigos vizinhos)
/// - Botão de lanterna com toggle on/off
/// - Feedback visual ao detectar código (borda verde piscante)
/// - Retorna o valor do código lido via `Navigator.pop(context, codigo)`
///
/// Uso:
/// ```dart
/// final codigo = await Navigator.push<String>(
///   context,
///   MaterialPageRoute(builder: (_) => const StoxScannerPage()),
/// );
/// if (codigo != null) { /* usar codigo */ }
/// ```
///
/// Com título personalizado:
/// ```dart
/// StoxScannerPage(titulo: 'Escanear item do inventário')
/// ```
class StoxScannerPage extends StatefulWidget {
  /// Título exibido na AppBar.
  final String titulo;

  const StoxScannerPage({
    super.key,
    this.titulo = 'Escanear Código',
  });

  @override
  State<StoxScannerPage> createState() => _StoxScannerPageState();
}

class _StoxScannerPageState extends State<StoxScannerPage>
    with SingleTickerProviderStateMixin {
  final _controller = MobileScannerController();

  bool _detectado = false;
  bool _lantErna = false;
  String? _ultimoCodigo;

  late AnimationController _animController;
  late Animation<double> _opacidadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _opacidadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _animController.dispose();
    super.dispose();
  }

  // ── Detecção ──────────────────────────────────────────────────────────────

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_detectado) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final codigo = barcodes.first.rawValue ?? '';
    if (codigo.isEmpty) return;

    _detectado = true;
    _ultimoCodigo = codigo;

    HapticFeedback.mediumImpact();
    await StoxAudio.play('sounds/beep.mp3');
    await _animController.forward();
    await Future.delayed(const Duration(milliseconds: 400));

    if (mounted) Navigator.pop(context, codigo);
  }

  // ── Lanterna ──────────────────────────────────────────────────────────────

  Future<void> _toggleLanterna() async {
    HapticFeedback.selectionClick();
    await _controller.toggleTorch();
    setState(() => _lantErna = !_lantErna);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    final scanWindow = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.42),
      width: size.width * 0.72,
      height: size.width * 0.45,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.titulo,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              _lantErna
                  ? Icons.flashlight_on_rounded
                  : Icons.flashlight_off_rounded,
              color: _lantErna ? Colors.yellow : Colors.white70,
            ),
            tooltip: _lantErna ? 'Apagar lanterna' : 'Acender lanterna',
            onPressed: _toggleLanterna,
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Camera feed ──
          MobileScanner(
            controller: _controller,
            scanWindow: scanWindow,
            onDetect: _onDetect,
          ),

          // ── Overlay escuro com buraco no viewfinder ──
          ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withAlpha(179),
              BlendMode.srcOut,
            ),
            child: Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    backgroundBlendMode: BlendMode.dstOut,
                  ),
                ),
                Positioned(
                  left: scanWindow.left,
                  top: scanWindow.top,
                  width: scanWindow.width,
                  height: scanWindow.height,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Borda do viewfinder ──
          Positioned(
            left: scanWindow.left,
            top: scanWindow.top,
            width: scanWindow.width,
            height: scanWindow.height,
            child: AnimatedBuilder(
              animation: _opacidadeAnim,
              builder: (_, _) {
                final cor = Color.lerp(
                  Colors.white,
                  Colors.green.shade400,
                  _opacidadeAnim.value,
                )!;
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: cor,
                      width: _detectado ? 4 : 2.5,
                    ),
                    color: _detectado
                        ? Colors.green.withAlpha(30)
                        : Colors.transparent,
                  ),
                );
              },
            ),
          ),

          // ── Cantos decorativos ──
          ..._buildCantos(scanWindow),

          // ── Linha de scan animada ──
          if (!_detectado) _buildLinhaScan(scanWindow),

          // ── Textos de instrução ──
          Positioned(
            top: scanWindow.bottom + 28,
            left: 24,
            right: 24,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _detectado
                  ? Column(
                      key: const ValueKey('detectado'),
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: Colors.green.shade400,
                          size: 36,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _ultimoCodigo ?? '',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Código lido com sucesso!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.green.shade300,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      key: const ValueKey('aguardando'),
                      children: [
                        Text(
                          'Alinhe o código de barras dentro do quadro',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withAlpha(220),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Apenas códigos dentro da área serão lidos',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withAlpha(120),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
            ),
          ),

          // ── Botão digitar manualmente ──
          Positioned(
            bottom: 48 + MediaQuery.of(context).viewPadding.bottom,
            left: 32,
            right: 32,
            child: TextButton.icon(
              onPressed: _digitarManualmente,
              icon: const Icon(Icons.keyboard_rounded, color: Colors.white70),
              label: const Text(
                'Digitar código manualmente',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Cantos decorativos ────────────────────────────────────────────────────

  List<Widget> _buildCantos(Rect scan) {
    const tam = 24.0;
    const esp = 3.5;
    final cor = _detectado ? Colors.green.shade400 : Colors.white;

    Widget canto(double left, double top, bool flipH, bool flipV) {
      return Positioned(
        left: left,
        top: top,
        child: Transform.scale(
          scaleX: flipH ? -1 : 1,
          scaleY: flipV ? -1 : 1,
          child: CustomPaint(
            size: const Size(tam, tam),
            painter: _CantoPainter(cor, esp),
          ),
        ),
      );
    }

    return [
      canto(scan.left - esp, scan.top - esp, false, false),
      canto(scan.right - tam + esp, scan.top - esp, true, false),
      canto(scan.left - esp, scan.bottom - tam + esp, false, true),
      canto(scan.right - tam + esp, scan.bottom - tam + esp, true, true),
    ];
  }

  // ── Linha de scan ─────────────────────────────────────────────────────────

  Widget _buildLinhaScan(Rect scan) => _LinhaScanAnimada(scanWindow: scan);

  // ── Digitar manualmente ───────────────────────────────────────────────────

  Future<void> _digitarManualmente() async {
    HapticFeedback.selectionClick();
    final editController = TextEditingController();

    final codigo = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text(
          'Digitar Código',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: editController,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Código do item',
            prefixIcon: Icon(Icons.inventory_2_outlined),
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.pop(dialogCtx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(dialogCtx, editController.text.trim()),
            child: const Text('CONFIRMAR'),
          ),
        ],
      ),
    );

    if (codigo != null && codigo.isNotEmpty && mounted) {
      Navigator.pop(context, codigo);
    }
  }
}

// ── Painter dos cantos do viewfinder ─────────────────────────────────────────

class _CantoPainter extends CustomPainter {
  final Color cor;
  final double espessura;
  const _CantoPainter(this.cor, this.espessura);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = cor
      ..strokeWidth = espessura
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const comprimento = 20.0;
    canvas.drawLine(Offset.zero, const Offset(comprimento, 0), paint);
    canvas.drawLine(Offset.zero, const Offset(0, comprimento), paint);
  }

  @override
  bool shouldRepaint(_CantoPainter old) => old.cor != cor;
}

// ── Linha de scan animada ─────────────────────────────────────────────────────

class _LinhaScanAnimada extends StatefulWidget {
  final Rect scanWindow;
  const _LinhaScanAnimada({required this.scanWindow});

  @override
  State<_LinhaScanAnimada> createState() => _LinhaScanAnimadaState();
}

class _LinhaScanAnimadaState extends State<_LinhaScanAnimada>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, _) {
        final y = widget.scanWindow.top +
            _anim.value * widget.scanWindow.height;
        return Positioned(
          left: widget.scanWindow.left + 12,
          top: y,
          width: widget.scanWindow.width - 24,
          height: 2,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.green.shade400.withAlpha(200),
                  Colors.green.shade400,
                  Colors.green.shade400.withAlpha(200),
                  Colors.transparent,
                ],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      },
    );
  }
}