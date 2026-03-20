import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/label_config.dart';
import '../services/stox_audio.dart';
import '../widgets/widgets.dart';

/// Tela de preview e impressão de etiquetas térmicas via Bluetooth.
///
/// Suporta impressão de item único ou lote (via [itenslote]).
/// A configuração do layout é persistida em [LabelConfig].
class EtiquetaPage extends StatefulWidget {
  final Map<String, dynamic>        itemData;
  final String                      deposito;
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

  List<BluetoothDevice> _devices       = [];
  BluetoothDevice?      _selectedDevice;
  bool _isPrinting   = false;
  int  _printedCount = 0;

  LabelConfig    _config        = LabelConfig();
  late TabController _tabController;

  late TextEditingController _cab1Controller;
  late TextEditingController _cab2Controller;
  late TextEditingController _rodapeController;
  late TextEditingController _copiasController;

  bool get _isLote =>
      widget.itenslote != null && widget.itenslote!.isNotEmpty;

  List<Map<String, dynamic>> get _itensParaImprimir =>
      _isLote ? widget.itenslote! : [widget.itemData];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _carregarConfig();
    _solicitarPermissoes();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _cab1Controller.dispose();
    _cab2Controller.dispose();
    _rodapeController.dispose();
    _copiasController.dispose();
    super.dispose();
  }

  // ── Configuração ──────────────────────────────────────────────────────────

  Future<void> _carregarConfig() async {
    final config = await LabelConfig.carregar();
    if (!mounted) return;
    setState(() => _config = config);
    _cab1Controller   = TextEditingController(text: config.cabecalhoLinha1);
    _cab2Controller   = TextEditingController(text: config.cabecalhoLinha2);
    _rodapeController = TextEditingController(text: config.rodapeTexto);
    _copiasController = TextEditingController(text: config.copiasPorItem.toString());
  }

  Future<void> _solicitarPermissoes() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
    if (statuses[Permission.bluetoothConnect]!.isGranted) {
      _buscarDispositivosBluetooth();
    }
  }

  Future<void> _buscarDispositivosBluetooth() async {
    try {
      final devices = await _bluetooth.getBondedDevices();
      if (mounted) setState(() => _devices = devices);
    } catch (e) {
      if (kDebugMode) debugPrint('EtiquetaPage._buscarDispositivosBluetooth: $e');
    }
  }

  Future<void> _salvarConfig() async {
    FocusScope.of(context).unfocus();
    final novaConfig = _config.copyWith(
      cabecalhoLinha1: _cab1Controller.text.trim(),
      cabecalhoLinha2: _cab2Controller.text.trim(),
      rodapeTexto:     _rodapeController.text.trim(),
      copiasPorItem:   int.tryParse(_copiasController.text)?.clamp(1, 99) ?? 1,
    );
    await novaConfig.salvar();
    await StoxAudio.play('sounds/check.mp3');
    if (!mounted) return;
    setState(() => _config = novaConfig);
    StoxSnackbar.sucesso(context, 'Configurações salvas!');
    _tabController.animateTo(0);
  }

  // ── Impressão ─────────────────────────────────────────────────────────────

  Future<void> _imprimir() async {
    if (_selectedDevice == null) {
      await StoxAudio.play('sounds/error_beep.mp3', isError: true);
      if (!mounted) return;
      StoxSnackbar.aviso(context, 'Selecione uma impressora primeiro.');
      return;
    }

    HapticFeedback.lightImpact();
    setState(() {
      _isPrinting   = true;
      _printedCount = 0;
    });

    try {
      final conectado = await _bluetooth.isConnected ?? false;
      if (!conectado) await _bluetooth.connect(_selectedDevice!);

      for (final item in _itensParaImprimir) {
        for (int i = 0; i < _config.copiasPorItem; i++) {
          await _imprimirItem(item);
          await StoxAudio.play('sounds/beep.mp3');
        }
        if (mounted) setState(() => _printedCount++);
      }

      await _bluetooth.disconnect();

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
      if (!mounted) return;
      StoxSnackbar.erro(context, 'Erro de impressão: $e');
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  /// Envia os comandos ESC/POS de um item para a impressora Bluetooth.
  Future<void> _imprimirItem(Map<String, dynamic> item) async {
    final codigo  = item['ItemCode']?.toString()    ?? '000';
    final nome    = item['ItemName']?.toString()    ?? '';
    final dep     = item['_deposito']?.toString()   ?? widget.deposito;
    final unidade = item['InventoryUOM']?.toString() ?? '';

    _bluetooth.printNewLine();
    if (_config.mostrarCabecalho && _config.cabecalhoLinha1.isNotEmpty) {
      _bluetooth.printCustom(_config.cabecalhoLinha1, 2, 1);
    }
    if (_config.mostrarCabecalho && _config.cabecalhoLinha2.isNotEmpty) {
      _bluetooth.printCustom(_config.cabecalhoLinha2, 1, 1);
    }
    _bluetooth.printCustom('--------------------------------', 0, 1);
    if (_config.mostrarNomeItem && nome.isNotEmpty) {
      _bluetooth.printCustom(nome, 1, 1);
    }
    _bluetooth.printNewLine();
    if (_config.mostrarCodigoBarras) {
      _bluetooth.printQRcode(codigo, 150, 150, 1);
    }
    if (_config.mostrarCodigoTexto) {
      _bluetooth.printCustom(codigo, 1, 1);
    }
    _bluetooth.printNewLine();

    final infoLinha = [
      if (_config.mostrarDeposito) 'DEP: $dep',
      if (_config.mostrarUnidade && unidade.isNotEmpty) 'UM: $unidade',
    ].join('  ');
    if (infoLinha.isNotEmpty) _bluetooth.printCustom(infoLinha, 0, 1);

    if (_config.mostrarRodape && _config.rodapeTexto.isNotEmpty) {
      _bluetooth.printCustom(_config.rodapeTexto, 0, 1);
    }
    _bluetooth.printNewLine();
    _bluetooth.printNewLine();

    if (_isLote) await Future.delayed(const Duration(milliseconds: 200));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLote
            ? 'Imprimir ${_itensParaImprimir.length} etiquetas'
            : 'Impressão de Etiqueta'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.preview_rounded), text: 'Preview'),
            Tab(icon: Icon(Icons.tune_rounded),    text: 'Configurar'),
          ],
        ),
      ),
      body: Column(children: [
        _buildSeletorImpressora(),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [_buildPreviewTab(), _buildConfigTab()],
          ),
        ),
        _buildBotaoImprimir(),
      ]),
    );
  }

  // ── Subwidgets ────────────────────────────────────────────────────────────

  Widget _buildSeletorImpressora() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
        ],
      ),
      child: Row(children: [
        Icon(Icons.print_rounded, color: Theme.of(context).primaryColor),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<BluetoothDevice>(
              isExpanded: true,
              hint: const Text('Selecione a Impressora'),
              value: _selectedDevice,
              items: _devices
                  .map((d) => DropdownMenuItem(
                        value: d,
                        child: Text(d.name ?? 'Dispositivo Desconhecido'),
                      ))
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
      ]),
    );
  }

  Widget _buildPreviewTab() {
    if (_isLote) return _buildPreviewLote();
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(child: _buildVisualEtiqueta(widget.itemData)),
    );
  }

  Widget _buildPreviewLote() {
    return Column(children: [
      StoxCard(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Icon(Icons.info_outline_rounded,
              color: Colors.blue.shade700, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${_itensParaImprimir.length} itens  •  '
              '${_config.copiasPorItem} cópia${_config.copiasPorItem != 1 ? 's' : ''} cada  •  '
              'Total: ${_itensParaImprimir.length * _config.copiasPorItem} etiquetas',
              style: TextStyle(fontSize: 13, color: Colors.blue.shade800),
            ),
          ),
        ]),
      ),
      if (_isPrinting)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(children: [
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
          ]),
        ),
      Expanded(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
          itemCount: _itensParaImprimir.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final item = _itensParaImprimir[index];
            return StoxCard(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor.withAlpha(26),
                  child: Icon(Icons.label_rounded,
                      color: Theme.of(context).primaryColor, size: 20),
                ),
                title: Text(item['ItemCode'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(item['ItemName'] ?? ''),
                trailing: Text(
                  '× ${_config.copiasPorItem}',
                  style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold),
                ),
              ),
            );
          },
        ),
      ),
    ]);
  }

  Widget _buildConfigTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle('Cabeçalho da Etiqueta'),
          SwitchListTile.adaptive(
            title: const Text('Mostrar cabeçalho'),
            value: _config.mostrarCabecalho,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              setState(() => _config = _config.copyWith(mostrarCabecalho: v));
            },
            contentPadding: EdgeInsets.zero,
          ),
          if (_config.mostrarCabecalho) ...[
            const SizedBox(height: 8),
            StoxTextField(
              controller: _cab1Controller,
              labelText: 'Linha 1 (ex: GRUPO JCN)',
              prefixIcon: Icons.title_rounded,
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 12),
            StoxTextField(
              controller: _cab2Controller,
              labelText: 'Linha 2 (opcional)',
              prefixIcon: Icons.subtitles_rounded,
              textCapitalization: TextCapitalization.words,
            ),
          ],
          const SizedBox(height: 20),
          const Divider(),

          _sectionTitle('Campos do Item'),
          _switchItem('Nome do item', _config.mostrarNomeItem,
              (v) => setState(() => _config = _config.copyWith(mostrarNomeItem: v))),
          _switchItem('Código de barras (QR)', _config.mostrarCodigoBarras,
              (v) => setState(() => _config = _config.copyWith(mostrarCodigoBarras: v))),
          _switchItem('Código em texto', _config.mostrarCodigoTexto,
              (v) => setState(() => _config = _config.copyWith(mostrarCodigoTexto: v))),
          _switchItem('Depósito', _config.mostrarDeposito,
              (v) => setState(() => _config = _config.copyWith(mostrarDeposito: v))),
          _switchItem('Unidade de medida', _config.mostrarUnidade,
              (v) => setState(() => _config = _config.copyWith(mostrarUnidade: v))),
          const SizedBox(height: 8),
          const Divider(),

          _sectionTitle('Rodapé'),
          SwitchListTile.adaptive(
            title: const Text('Mostrar rodapé'),
            value: _config.mostrarRodape,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              setState(() => _config = _config.copyWith(mostrarRodape: v));
            },
            contentPadding: EdgeInsets.zero,
          ),
          if (_config.mostrarRodape) ...[
            const SizedBox(height: 8),
            StoxTextField(
              controller: _rodapeController,
              labelText: 'Texto do rodapé (ex: VER. 1.0)',
              prefixIcon: Icons.text_snippet_rounded,
            ),
          ],
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

  /// Preview estático da etiqueta no tamanho 260×160 px.
  Widget _buildVisualEtiqueta(Map<String, dynamic> item) {
    final codigo = item['ItemCode']?.toString() ?? '000';
    final nome   = item['ItemName']?.toString() ?? '';
    final dep    = item['_deposito']?.toString() ?? widget.deposito;

    const previewWidth  = 260.0;
    const previewHeight = 160.0;

    return Container(
      width: previewWidth,
      height: previewHeight,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 6))
        ],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (_config.mostrarCabecalho && _config.cabecalhoLinha1.isNotEmpty) ...[
            Text(_config.cabecalhoLinha1,
                style: const TextStyle(
                    fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
            if (_config.cabecalhoLinha2.isNotEmpty)
              Text(_config.cabecalhoLinha2,
                  style: TextStyle(fontSize: 8, color: Colors.grey.shade600)),
            const Divider(height: 8),
          ],
          if (_config.mostrarNomeItem && nome.isNotEmpty) ...[
            Text(nome,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
          ],
          if (_config.mostrarCodigoBarras) ...[
            Flexible(
              child: BarcodeWidget(
                barcode:  Barcode.code128(),
                data:     codigo.isEmpty ? '000' : codigo,
                width:    previewWidth - 40,
                height:   38,
                drawText: false,
              ),
            ),
            const SizedBox(height: 4),
          ],
          if (_config.mostrarCodigoTexto)
            Text(codigo,
                style: const TextStyle(
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w600,
                    fontSize: 12)),
          if (_config.mostrarDeposito || _config.mostrarRodape) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_config.mostrarDeposito)
                  Text('DEP: $dep',
                      style: const TextStyle(
                          fontSize: 9, fontWeight: FontWeight.bold)),
                if (_config.mostrarRodape && _config.rodapeTexto.isNotEmpty)
                  Text(_config.rodapeTexto,
                      style: TextStyle(fontSize: 8, color: Colors.grey.shade500)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBotaoImprimir() {
    final total = _itensParaImprimir.length * _config.copiasPorItem;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))
        ],
      ),
      child: StoxButton(
        label: _isPrinting
            ? 'Imprimindo $_printedCount de ${_itensParaImprimir.length}...'
            : _isLote
                ? 'IMPRIMIR $total ETIQUETA${total != 1 ? 'S' : ''}'
                : 'IMPRIMIR ETIQUETA',
        icon:    _isPrinting ? null : Icons.print_rounded,
        loading: _isPrinting,
        onPressed: _imprimir,
        height: 54,
      ),
    );
  }
}