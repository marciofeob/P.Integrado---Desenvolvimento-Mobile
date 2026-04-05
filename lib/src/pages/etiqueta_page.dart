import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:barcode_widget/barcode_widget.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart';
import 'package:printing/printing.dart';

import '../models/label_config.dart';
import '../services/stox_audio.dart';
import '../widgets/widgets.dart';

/// Modo de envio da etiqueta para impressão.
enum _ModoImpressao {
  /// Impressão via sistema (WiFi, USB, AirPrint).
  rede,

  /// Impressão direta via Bluetooth (TSPL ou ESC/POS).
  bluetooth,
}

/// Tela de impressão de etiquetas com código de barras.
///
/// Suporta dois modos de impressão:
/// - **Rede/WiFi**: gera PDF e envia via `printing` (AirPrint, etc.)
/// - **Bluetooth**: envia comandos direto para impressora térmica
///   - **TSPL**: PT-260, Argox, TSC e compatíveis
///   - **ESC/POS**: MPT-260, Rongta, Munbyn, Epson e compatíveis
class EtiquetaPage extends StatefulWidget {
  final Map<String, dynamic> itemData;
  final String deposito;
  final List<Map<String, dynamic>>? itenslote;

  const EtiquetaPage({
    super.key,
    required this.itemData,
    required this.deposito,
    this.itenslote,
  });

  @override
  State<EtiquetaPage> createState() => _EtiquetaPageState();
}

class _EtiquetaPageState extends State<EtiquetaPage>
    with SingleTickerProviderStateMixin {
  final _bluetooth = BlueThermalPrinter.instance;

  List<BluetoothDevice> _devices = [];
  BluetoothDevice? _selectedDevice;
  bool _isPrinting = false;
  int _printedCount = 0;
  bool _isConnected = false;

  LabelConfig _config = LabelConfig();
  _ModoImpressao _modo = _ModoImpressao.rede;
  late TabController _tabController;

  final _copiasController = TextEditingController(text: '1');
  final _larguraController = TextEditingController(text: '60');
  final _alturaController = TextEditingController(text: '40');

  bool get _isLote => widget.itenslote != null && widget.itenslote!.isNotEmpty;

  List<Map<String, dynamic>> get _itensParaImprimir =>
      _isLote ? widget.itenslote! : [widget.itemData];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _carregarConfig();
    _initBluetooth();
  }

  @override
  void dispose() {
    _disconnectBluetooth();
    _tabController.dispose();
    _copiasController.dispose();
    _larguraController.dispose();
    _alturaController.dispose();
    super.dispose();
  }

  // ── Bluetooth — inicialização e conexão ───────────────────────────────────

  Future<void> _initBluetooth() async {
    try {
      final isConnected = await _bluetooth.isConnected ?? false;
      if (mounted && isConnected) setState(() => _isConnected = true);
    } catch (e) {
      if (kDebugMode) debugPrint('EtiquetaPage._initBluetooth: $e');
    }
  }

  Future<void> _disconnectBluetooth() async {
    if (_isConnected) {
      try {
        await _bluetooth.disconnect();
      } catch (e) {
        if (kDebugMode) debugPrint('EtiquetaPage._disconnectBluetooth: $e');
      }
    }
    _isConnected = false;
  }

  Future<void> _solicitarPermissoesBluetooth() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetooth,
      Permission.location,
    ].request();

    if (statuses[Permission.bluetoothConnect]!.isGranted ||
        statuses[Permission.bluetooth]!.isGranted) {
      _buscarDispositivosBluetooth();
    } else {
      if (mounted) {
        StoxSnackbar.aviso(context, 'Permissão Bluetooth necessária');
      }
    }
  }

  Future<void> _buscarDispositivosBluetooth() async {
    try {
      final devices = await _bluetooth.getBondedDevices();
      if (mounted) setState(() => _devices = devices);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('EtiquetaPage._buscarDispositivosBluetooth: $e');
      }
      if (mounted) {
        StoxSnackbar.erro(context, 'Erro ao buscar dispositivos Bluetooth');
      }
    }
  }

  Future<bool> _conectarBluetooth() async {
    if (_selectedDevice == null) {
      StoxSnackbar.aviso(context, 'Selecione uma impressora');
      return false;
    }

    try {
      setState(() => _isPrinting = true);

      if (_isConnected) {
        await _bluetooth.disconnect();
        _isConnected = false;
        await Future.delayed(const Duration(milliseconds: 500));
      }

      final connected = await _bluetooth.connect(_selectedDevice!);
      if (connected != null && connected) {
        _isConnected = true;
        await Future.delayed(const Duration(milliseconds: 500));
        return true;
      } else {
        throw Exception('Falha na conexão');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('EtiquetaPage._conectarBluetooth: $e');
      if (mounted) {
        StoxSnackbar.erro(context, 'Não foi possível conectar na impressora');
      }
      setState(() => _isPrinting = false);
      return false;
    }
  }

  // ── Configuração ──────────────────────────────────────────────────────────

  Future<void> _carregarConfig() async {
    final config = await LabelConfig.carregar();
    if (!mounted) return;
    setState(() => _config = config);
    _copiasController.text = config.copiasPorItem.toString();
    _larguraController.text = config.larguraMm.toString();
    _alturaController.text = config.alturaMm.toString();
  }

  Future<void> _salvarConfig() async {
    FocusScope.of(context).unfocus();

    final largura = int.tryParse(_larguraController.text)?.clamp(20, 200) ?? 60;
    final altura = int.tryParse(_alturaController.text)?.clamp(15, 200) ?? 40;

    final novaConfig = _config.copyWith(
      larguraMm: largura,
      alturaMm: altura,
      copiasPorItem: int.tryParse(_copiasController.text)?.clamp(1, 99) ?? 1,
    );
    await novaConfig.salvar();
    await StoxAudio.play('sounds/check.mp3');
    if (!mounted) return;
    setState(() => _config = novaConfig);
    StoxSnackbar.sucesso(context, 'Configurações salvas!');
    _tabController.animateTo(0);
  }

  // ── TSPL — protocolo para PT-260 e compatíveis ────────────────────────────

  Future<void> _enviarComandoTSPL(String comando) async {
    final bytes = utf8.encode('$comando\r\n');
    await _bluetooth.writeBytes(Uint8List.fromList(bytes));
    if (kDebugMode) debugPrint('TSPL >> $comando');
    await Future.delayed(const Duration(milliseconds: 50));
  }

  Future<void> _inicializarImpressoraTSPL() async {
    await _enviarComandoTSPL('SIZE ${_config.larguraMm}, ${_config.alturaMm}');
    await _enviarComandoTSPL('GAP 0, 0');
    await _enviarComandoTSPL('DIRECTION 1');
    await _enviarComandoTSPL('REFERENCE 0,0');
    await _enviarComandoTSPL('SPEED 4');
    await _enviarComandoTSPL('DENSITY 12');
  }

  /// Imprime uma etiqueta via protocolo TSPL (PT-260 e compatíveis).
  Future<void> _imprimirEtiquetaTSPL(Map<String, dynamic> item) async {
    final codigo = item['ItemCode']?.toString() ?? '000';
    final nome = item['ItemName']?.toString() ?? '';
    final dep = item['_deposito']?.toString() ?? widget.deposito;

    final larguraDots = (_config.larguraMm * 8).toInt();
    final alturaDots = (_config.alturaMm * 8).toInt();
    const margemX = 16;
    final areaUtil = larguraDots - (margemX * 2);
    const alturaLinha = 24;
    const espacamento = 6;
    const charLargura = 8;
    const espacoExtra = 16;
    final charsMaxLinha = areaUtil ~/ charLargura;
    int yPos = 12;

    await _enviarComandoTSPL('CLS');

    // ── Nome do item ──
    if (_config.mostrarNomeItem && nome.isNotEmpty) {
      final nomeEscapado = _escapeTSPL(nome);
      if (nomeEscapado.length <= charsMaxLinha) {
        await _enviarComandoTSPL(
          'TEXT $margemX,$yPos,"0",1,1,1,"$nomeEscapado"',
        );
        yPos += alturaLinha;
      } else {
        int corte = nomeEscapado.lastIndexOf(' ', charsMaxLinha);
        if (corte <= 0) corte = charsMaxLinha;
        final linha1 = nomeEscapado.substring(0, corte).trim();
        final linha2 = nomeEscapado.substring(corte).trim();
        await _enviarComandoTSPL('TEXT $margemX,$yPos,"0",1,1,1,"$linha1"');
        yPos += alturaLinha;
        if (linha2.isNotEmpty) {
          final l2 = linha2.length > charsMaxLinha
              ? '${linha2.substring(0, charsMaxLinha - 3)}...'
              : linha2;
          await _enviarComandoTSPL('TEXT $margemX,$yPos,"0",1,1,1,"$l2"');
          yPos += alturaLinha;
        }
      }
      yPos += espacoExtra;
    }

    // ── Código de barras Code128 (centralizado) ──
    if (_config.mostrarCodigoBarras && codigo.isNotEmpty) {
      final temLinhaAbaixo =
          _config.mostrarCodigoTexto || _config.mostrarDeposito;
      final espacoBottom = temLinhaAbaixo ? alturaLinha + espacamento + 12 : 12;
      final alturaBarcode = (alturaDots - yPos - espacoBottom).clamp(25, 100);
      final modulosBarcode = 35 + (codigo.length * 11);
      final larguraBarcode = modulosBarcode * 2;
      final barcodeX = ((larguraDots - larguraBarcode) ~/ 2).clamp(
        margemX,
        larguraDots ~/ 4,
      );

      await _enviarComandoTSPL(
        'BARCODE $barcodeX,$yPos,"128",$alturaBarcode,0,0,2,2,'
        '"${_escapeTSPL(codigo)}"',
      );
      yPos += alturaBarcode + espacamento;
    }

    // ── Código + depósito ──
    final infoLine = <String>[];
    if (_config.mostrarCodigoTexto) infoLine.add(codigo);
    if (_config.mostrarDeposito) infoLine.add('DEP: $dep');
    if (infoLine.isNotEmpty) {
      await _enviarComandoTSPL(
        'TEXT $margemX,$yPos,"0",1,1,1,"${_escapeTSPL(infoLine.join(' - '))}"',
      );
    }

    await _enviarComandoTSPL('PRINT 1,1');
  }

  // ── ESC/POS — protocolo para GoldenSky e compatíveis ─────────────────────

  /// Envia bytes brutos ESC/POS para a impressora.
  Future<void> _enviarBytesEscPos(List<int> bytes) async {
    await _bluetooth.writeBytes(Uint8List.fromList(bytes));
    await Future.delayed(const Duration(milliseconds: 30));
  }

  /// Inicializa a impressora ESC/POS (reset + encoding).
  Future<void> _inicializarImpressoraEscPos() async {
    await _enviarBytesEscPos([0x1B, 0x40]); // ESC @ — reset
    await _enviarBytesEscPos([0x1B, 0x74, 0x00]); // ESC t — codepage PC437
    // SEM ESC C — Label Mode já ativa o sensor de gap automaticamente
  }

  /// Imprime uma etiqueta via protocolo ESC/POS.
  ///
  /// Comandos utilizados:
  /// - ESC @  : reset
  /// - ESC a  : alinhamento centralizado
  /// - ESC E  : bold on/off
  /// - ESC !  : seleção de fonte
  /// - GS h   : altura do barcode
  /// - GS w   : largura do módulo do barcode
  /// - GS H   : posição do texto HRI
  /// - GS k   : impressão de barcode Code128
  /// - LF     : quebra de linha
  /// - ESC d  : avança N linhas (separa etiquetas)

  Future<void> _imprimirEtiquetaEscPos(Map<String, dynamic> item) async {
    final codigo = (item['ItemCode']?.toString() ?? '000').toUpperCase();
    final nome = item['ItemName']?.toString() ?? '';
    final dep = item['_deposito']?.toString() ?? widget.deposito;

    final alturaBarcode = (_config.alturaMm * 2).clamp(50, 150);

    // ── Reset ──
    await _enviarBytesEscPos([0x1B, 0x40]);

    // Tudo centralizado
    await _enviarBytesEscPos([0x1B, 0x61, 0x01]);

    // ── 1/2 linha em branco antes do título ──
    await _enviarBytesEscPos([0x1B, 0x33, 0x08]); // ESC 3 — define espaçamento
    await _enviarBytesEscPos([0x0A]); // LF — avança a meia linha
    await _enviarBytesEscPos([0x1B, 0x32]); // ESC 2 — restaura padrão

    // ── Nome — bold + centralizado ──
    if (_config.mostrarNomeItem && nome.isNotEmpty) {
      await _enviarBytesEscPos([0x1B, 0x45, 0x01]); // bold on
      await _enviarBytesEscPos([0x1B, 0x21, 0x00]); // fonte normal
      await _enviarBytesEscPos(_encodeEscPos(_escapeTSPL(nome)));
      await _enviarBytesEscPos([0x0A]);
      await _enviarBytesEscPos([0x1B, 0x45, 0x00]); // bold off
    }

    // ── Código de barras Code128 — centralizado ──
    if (_config.mostrarCodigoBarras && codigo.isNotEmpty) {
      final hriPos = _config.mostrarCodigoTexto ? 0x02 : 0x00;
      await _enviarBytesEscPos([0x1D, 0x48, hriPos]); // HRI abaixo
      await _enviarBytesEscPos([0x1D, 0x68, alturaBarcode]); // altura
      await _enviarBytesEscPos([0x1D, 0x77, 0x02]); // largura módulo

      // ← FIX: {B = subset B (alfanumérico). {C era errado — só aceita pares de dígitos
      final dadosCode128 = '{B$codigo';
      final dataBytes = _encodeEscPos(dadosCode128);
      await _enviarBytesEscPos([0x1D, 0x6B, 0x49, dataBytes.length]);
      await _enviarBytesEscPos(dataBytes);
      await Future.delayed(const Duration(milliseconds: 150));
      await _enviarBytesEscPos([0x0A]);
    }

    // ── Depósito — bold + centralizado ──
    if (_config.mostrarDeposito) {
      await _enviarBytesEscPos([0x1B, 0x45, 0x01]); // bold on
      await _enviarBytesEscPos(_encodeEscPos('DEP: $dep'));
      await _enviarBytesEscPos([0x0A]);
      await _enviarBytesEscPos([0x1B, 0x45, 0x00]); // bold off
    }

    // ── Avança papel ──
    await _enviarBytesEscPos([0x1B, 0x64, 0x04]);
  }

  /// Codifica string para bytes Latin-1 compatível com ESC/POS.
  List<int> _encodeEscPos(String text) {
    return text.codeUnits.map((c) => c > 255 ? 0x3F : c).toList();
  }

  // ── Transliteração compartilhada ──────────────────────────────────────────

  String _escapeTSPL(String text) {
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(_tsplCharMap[text[i]] ?? text[i]);
    }
    return buffer.toString().replaceAll('"', '\\"').replaceAll('\n', ' ');
  }

  static const _tsplCharMap = {
    'á': 'a',
    'à': 'a',
    'â': 'a',
    'ã': 'a',
    'ä': 'a',
    'Á': 'A',
    'À': 'A',
    'Â': 'A',
    'Ã': 'A',
    'Ä': 'A',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'É': 'E',
    'È': 'E',
    'Ê': 'E',
    'Ë': 'E',
    'í': 'i',
    'ì': 'i',
    'î': 'i',
    'ï': 'i',
    'Í': 'I',
    'Ì': 'I',
    'Î': 'I',
    'Ï': 'I',
    'ó': 'o',
    'ò': 'o',
    'ô': 'o',
    'õ': 'o',
    'ö': 'o',
    'Ó': 'O',
    'Ò': 'O',
    'Ô': 'O',
    'Õ': 'O',
    'Ö': 'O',
    'ú': 'u',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'Ú': 'U',
    'Ù': 'U',
    'Û': 'U',
    'Ü': 'U',
    'ç': 'c',
    'Ç': 'C',
    'ñ': 'n',
    'Ñ': 'N',
    'ý': 'y',
    'Ý': 'Y',
    'ÿ': 'y',
    'ª': 'a',
    'º': 'o',
  };

  // ── Geração de PDF ────────────────────────────────────────────────────────

  pw.Page _gerarPaginaPdf(Map<String, dynamic> item) {
    final codigo = item['ItemCode']?.toString() ?? '000';
    final nome = item['ItemName']?.toString() ?? '';
    final dep = item['_deposito']?.toString() ?? widget.deposito;

    final larguraPt = _config.larguraMm * PdfPageFormat.mm;
    final alturaPt = _config.alturaMm * PdfPageFormat.mm;

    return pw.Page(
      pageFormat: PdfPageFormat(
        larguraPt,
        alturaPt,
        marginAll: 2 * PdfPageFormat.mm,
      ),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          if (_config.mostrarNomeItem && nome.isNotEmpty) ...[
            pw.Text(
              nome,
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.left,
              maxLines: 2,
            ),
            pw.SizedBox(height: 6),
          ],
          if (_config.mostrarCodigoBarras)
            pw.Expanded(
              child: pw.Center(
                child: pw.BarcodeWidget(
                  barcode: Barcode.code128(),
                  data: codigo.isEmpty ? '000' : codigo,
                  drawText: false,
                ),
              ),
            ),
          pw.SizedBox(height: 2),
          if (_config.mostrarCodigoTexto || _config.mostrarDeposito)
            pw.Text(
              [
                if (_config.mostrarCodigoTexto) codigo,
                if (_config.mostrarDeposito) 'DEP: $dep',
              ].join(' - '),
              style: pw.TextStyle(
                fontSize: 7,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
        ],
      ),
    );
  }

  // ── Impressão ─────────────────────────────────────────────────────────────

  Future<void> _imprimir() async {
    if (_modo == _ModoImpressao.bluetooth) {
      await _imprimirBluetooth();
    } else {
      await _imprimirSistema();
    }
  }

  Future<void> _imprimirSistema() async {
    HapticFeedback.lightImpact();
    setState(() {
      _isPrinting = true;
      _printedCount = 0;
    });

    try {
      final doc = pw.Document();
      for (final item in _itensParaImprimir) {
        for (int i = 0; i < _config.copiasPorItem; i++) {
          doc.addPage(_gerarPaginaPdf(item));
        }
        if (mounted) setState(() => _printedCount++);
      }

      final larguraPt = _config.larguraMm * PdfPageFormat.mm;
      final alturaPt = _config.alturaMm * PdfPageFormat.mm;

      await Printing.layoutPdf(
        onLayout: (_) => doc.save(),
        name: 'Etiqueta_STOX',
        format: PdfPageFormat(larguraPt, alturaPt),
      );

      await StoxAudio.play('sounds/check.mp3');
      if (!mounted) return;
      final total = _itensParaImprimir.length * _config.copiasPorItem;
      StoxSnackbar.sucesso(
        context,
        _isLote
            ? '$total etiqueta${total != 1 ? 's' : ''} enviada${total != 1 ? 's' : ''}!'
            : 'Etiqueta enviada para impressão!',
      );
    } catch (e) {
      await StoxAudio.play('sounds/fail.mp3', isFail: true);
      if (!mounted) return;
      StoxSnackbar.erro(context, 'Erro ao imprimir: $e');
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  Future<void> _imprimirBluetooth() async {
    if (_selectedDevice == null) {
      await StoxAudio.play('sounds/error_beep.mp3', isError: true);
      if (!mounted) return;
      StoxSnackbar.aviso(context, 'Selecione uma impressora Bluetooth.');
      return;
    }

    HapticFeedback.lightImpact();
    setState(() {
      _isPrinting = true;
      _printedCount = 0;
    });

    final usaEscPos = _config.protocoloBluetooth == ProtocoloBluetooth.escpos;

    try {
      final conectado = await _conectarBluetooth();
      if (!conectado) throw Exception('Falha na conexão');

      await Future.delayed(const Duration(milliseconds: 800));

      if (usaEscPos) {
        await _inicializarImpressoraEscPos();
      } else {
        await _inicializarImpressoraTSPL();
      }

      for (final item in _itensParaImprimir) {
        for (int i = 0; i < _config.copiasPorItem; i++) {
          if (usaEscPos) {
            await _imprimirEtiquetaEscPos(item);
          } else {
            await _imprimirEtiquetaTSPL(item);
          }
          await StoxAudio.play('sounds/beep.mp3');
          await Future.delayed(const Duration(milliseconds: 300));
        }
        if (mounted) setState(() => _printedCount++);
      }

      await Future.delayed(const Duration(seconds: 2));
      await _bluetooth.disconnect();
      _isConnected = false;

      await StoxAudio.play('sounds/check.mp3');
      if (!mounted) return;
      final total = _itensParaImprimir.length * _config.copiasPorItem;
      StoxSnackbar.sucesso(
        context,
        _isLote
            ? '$total etiqueta${total != 1 ? 's' : ''} impressa${total != 1 ? 's' : ''} com sucesso!'
            : 'Impressão enviada com sucesso!',
      );
    } catch (e) {
      await StoxAudio.play('sounds/fail.mp3', isFail: true);
      if (kDebugMode) debugPrint('EtiquetaPage._imprimirBluetooth: $e');
      if (!mounted) return;
      StoxSnackbar.erro(context, 'Erro de impressão: $e');
    } finally {
      if (mounted) setState(() => _isPrinting = false);
      await _disconnectBluetooth();
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isLote
              ? 'Imprimir ${_itensParaImprimir.length} etiquetas'
              : 'Impressão de Etiqueta',
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.preview_rounded), text: 'Preview'),
            Tab(icon: Icon(Icons.tune_rounded), text: 'Configurar'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildSeletorModo(),
          if (_modo == _ModoImpressao.bluetooth) ...[
            _buildSeletorImpressoraBluetooth(),
            _buildSeletorProtocolo(),
          ],
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildPreviewTab(), _buildConfigTab()],
            ),
          ),
          _buildBotaoImprimir(),
        ],
      ),
    );
  }

  // ── Seletor de modo ───────────────────────────────────────────────────────

  Widget _buildSeletorModo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildModoChip(
              icon: Icons.wifi_rounded,
              label: 'Rede / WiFi',
              ativo: _modo == _ModoImpressao.rede,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _modo = _ModoImpressao.rede);
                _disconnectBluetooth();
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildModoChip(
              icon: Icons.bluetooth_rounded,
              label: 'Bluetooth',
              ativo: _modo == _ModoImpressao.bluetooth,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _modo = _ModoImpressao.bluetooth);
                _solicitarPermissoesBluetooth();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModoChip({
    required IconData icon,
    required String label,
    required bool ativo,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: ativo
                ? theme.primaryColor.withAlpha(20)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: ativo ? theme.primaryColor : Colors.grey.shade300,
              width: ativo ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: ativo ? theme.primaryColor : Colors.grey.shade500,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: ativo ? FontWeight.bold : FontWeight.w500,
                  color: ativo ? theme.primaryColor : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Seletor de impressora Bluetooth ───────────────────────────────────────

  Widget _buildSeletorImpressoraBluetooth() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      color: Colors.white,
      child: Row(
        children: [
          Icon(Icons.print_rounded, color: Theme.of(context).primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<BluetoothDevice>(
                isExpanded: true,
                hint: const Text('Selecione a Impressora'),
                value: _selectedDevice,
                items: _devices
                    .map(
                      (d) => DropdownMenuItem(
                        value: d,
                        child: Text(d.name ?? 'Dispositivo Desconhecido'),
                      ),
                    )
                    .toList(),
                onChanged: (device) {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedDevice = device);
                },
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            color: Theme.of(context).primaryColor,
            tooltip: 'Atualizar dispositivos',
            onPressed: () {
              HapticFeedback.lightImpact();
              _buscarDispositivosBluetooth();
            },
          ),
        ],
      ),
    );
  }

  // ── Seletor de protocolo Bluetooth ────────────────────────────────────────

  Widget _buildSeletorProtocolo() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              'Protocolo de impressão:',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _buildProtocoloChip(
                  label: 'TSPL',
                  sublabel: 'PT-260 e compatíveis',
                  protocolo: ProtocoloBluetooth.tspl,
                  cor: Colors.blue.shade700,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildProtocoloChip(
                  label: 'ESC/POS',
                  sublabel: 'GoldenSky e compatíveis',
                  protocolo: ProtocoloBluetooth.escpos,
                  cor: Colors.purple.shade700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProtocoloChip({
    required String label,
    required String sublabel,
    required ProtocoloBluetooth protocolo,
    required Color cor,
  }) {
    final ativo = _config.protocoloBluetooth == protocolo;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          HapticFeedback.selectionClick();
          final novo = _config.copyWith(protocoloBluetooth: protocolo);
          await novo.salvar();
          if (mounted) setState(() => _config = novo);
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          decoration: BoxDecoration(
            color: ativo ? cor.withAlpha(18) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: ativo ? cor : Colors.grey.shade300,
              width: ativo ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    ativo
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    size: 14,
                    color: ativo ? cor : Colors.grey.shade400,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: ativo ? cor : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.only(left: 18),
                child: Text(
                  sublabel,
                  style: TextStyle(
                    fontSize: 10,
                    color: ativo ? cor.withAlpha(200) : Colors.grey.shade500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Tab: Preview ──────────────────────────────────────────────────────────

  Widget _buildPreviewTab() {
    if (_isLote) return _buildPreviewLote();
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(child: _buildVisualEtiqueta(widget.itemData)),
    );
  }

  Widget _buildPreviewLote() {
    return Column(
      children: [
        StoxCard(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: Colors.blue.shade700,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_itensParaImprimir.length} itens  •  '
                  '${_config.copiasPorItem} '
                  'cópia${_config.copiasPorItem != 1 ? 's' : ''} cada  •  '
                  'Total: ${_itensParaImprimir.length * _config.copiasPorItem} etiquetas',
                  style: TextStyle(fontSize: 13, color: Colors.blue.shade800),
                ),
              ),
            ],
          ),
        ),
        if (_isPrinting)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: _printedCount / _itensParaImprimir.length,
                  backgroundColor: Colors.grey.shade200,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(height: 8),
                Text(
                  'Imprimindo $_printedCount de ${_itensParaImprimir.length}...',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
            itemCount: _itensParaImprimir.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, index) {
              final item = _itensParaImprimir[index];
              return StoxCard(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(
                      context,
                    ).primaryColor.withAlpha(26),
                    child: Icon(
                      Icons.label_rounded,
                      color: Theme.of(context).primaryColor,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    item['ItemCode'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(item['ItemName'] ?? ''),
                  trailing: Text(
                    '× ${_config.copiasPorItem}',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Tab: Configuração ─────────────────────────────────────────────────────

  Widget _buildConfigTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle('Tamanho da Etiqueta'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: StoxTextField(
                  controller: _larguraController,
                  labelText: 'Largura (mm)',
                  prefixIcon: Icons.swap_horiz_rounded,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StoxTextField(
                  controller: _alturaController,
                  labelText: 'Altura (mm)',
                  prefixIcon: Icons.swap_vert_rounded,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Atual: ${_config.larguraMm} × ${_config.alturaMm} mm',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          _sectionTitle('Campos da Etiqueta'),
          _switchItem(
            'Nome do item',
            _config.mostrarNomeItem,
            (v) =>
                setState(() => _config = _config.copyWith(mostrarNomeItem: v)),
          ),
          _switchItem(
            'Código de barras',
            _config.mostrarCodigoBarras,
            (v) => setState(
              () => _config = _config.copyWith(mostrarCodigoBarras: v),
            ),
          ),
          _switchItem(
            'Código em texto',
            _config.mostrarCodigoTexto,
            (v) => setState(
              () => _config = _config.copyWith(mostrarCodigoTexto: v),
            ),
          ),
          _switchItem(
            'Depósito',
            _config.mostrarDeposito,
            (v) =>
                setState(() => _config = _config.copyWith(mostrarDeposito: v)),
          ),
          const SizedBox(height: 16),
          const Divider(),
          _sectionTitle('Cópias por Item'),
          const SizedBox(height: 8),
          StoxTextField(
            controller: _copiasController,
            labelText: 'Quantidade de cópias',
            prefixIcon: Icons.content_copy_rounded,
            keyboardType: TextInputType.number,
            helperText: 'Quantas etiquetas imprimir por item (1–99).',
          ),
          const SizedBox(height: 32),
          StoxOutlinedButton(
            label: 'SALVAR CONFIGURAÇÕES',
            icon: Icons.save_rounded,
            onPressed: _salvarConfig,
            height: 52,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 2),
    child: Text(
      title,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 14,
        color: Theme.of(context).primaryColor,
      ),
    ),
  );

  Widget _switchItem(String label, bool value, ValueChanged<bool> onChanged) =>
      SwitchListTile.adaptive(
        title: Text(label, style: const TextStyle(fontSize: 14)),
        value: value,
        onChanged: (v) {
          HapticFeedback.selectionClick();
          onChanged(v);
        },
        contentPadding: EdgeInsets.zero,
        dense: true,
      );

  // ── Preview visual da etiqueta ────────────────────────────────────────────

  Widget _buildVisualEtiqueta(Map<String, dynamic> item) {
    final codigo = item['ItemCode']?.toString() ?? '000';
    final nome = item['ItemName']?.toString() ?? '';
    final dep = item['_deposito']?.toString() ?? widget.deposito;

    const escala = 4.0;
    const maxLargura = 280.0;
    final larguraRaw = _config.larguraMm * escala;
    final fator = larguraRaw > maxLargura ? maxLargura / larguraRaw : 1.0;
    final previewW = larguraRaw * fator;
    final previewH = _config.alturaMm * escala * fator;

    return Column(
      children: [
        Container(
          width: previewW,
          height: previewH,
          padding: EdgeInsets.all(6 * fator),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_config.mostrarNomeItem && nome.isNotEmpty) ...[
                Text(
                  nome,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 9 * fator,
                  ),
                  textAlign: TextAlign.left,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 6 * fator),
              ],
              if (_config.mostrarCodigoBarras)
                Expanded(
                  child: Center(
                    child: BarcodeWidget(
                      barcode: Barcode.code128(),
                      data: codigo.isEmpty ? '000' : codigo,
                      width: previewW * 0.75,
                      drawText: false,
                    ),
                  ),
                ),
              SizedBox(height: 2 * fator),
              if (_config.mostrarCodigoTexto || _config.mostrarDeposito)
                Text(
                  [
                    if (_config.mostrarCodigoTexto) codigo,
                    if (_config.mostrarDeposito) 'DEP: $dep',
                  ].join(' - '),
                  style: TextStyle(
                    letterSpacing: 0.5,
                    fontWeight: FontWeight.w600,
                    fontSize: 8 * fator,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '${_config.larguraMm} × ${_config.alturaMm} mm',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
      ],
    );
  }

  // ── Botão de imprimir ─────────────────────────────────────────────────────

  Widget _buildBotaoImprimir() {
    final total = _itensParaImprimir.length * _config.copiasPorItem;
    final modoLabel = _modo == _ModoImpressao.rede
        ? 'IMPRIMIR'
        : 'IMPRIMIR VIA BT';

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        20 + MediaQuery.of(context).viewPadding.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: StoxButton(
        label: _isPrinting
            ? 'Imprimindo $_printedCount de ${_itensParaImprimir.length}...'
            : _isLote
            ? '$modoLabel $total ETIQUETA${total != 1 ? 'S' : ''}'
            : '$modoLabel ETIQUETA',
        icon: _isPrinting ? null : Icons.print_rounded,
        loading: _isPrinting,
        onPressed: _imprimir,
        height: 54,
      ),
    );
  }
}
