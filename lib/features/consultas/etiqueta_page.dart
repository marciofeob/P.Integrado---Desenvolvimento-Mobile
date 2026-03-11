import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:permission_handler/permission_handler.dart';

class EtiquetaPage extends StatefulWidget {
  final Map<String, dynamic> itemData;
  final String deposito;

  const EtiquetaPage({super.key, required this.itemData, required this.deposito});

  @override
  State<EtiquetaPage> createState() => _EtiquetaPageState();
}

class _EtiquetaPageState extends State<EtiquetaPage> {
  BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;
  List<BluetoothDevice> _devices = [];
  BluetoothDevice? _selectedDevice;
  bool _isPrinting = false;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    if (statuses[Permission.bluetoothConnect]!.isGranted) {
      _getBluetoothDevices();
    }
  }

  void _getBluetoothDevices() async {
    try {
      List<BluetoothDevice> devices = await bluetooth.getBondedDevices();
      setState(() {
        _devices = devices;
      });
    } catch (e) {
      debugPrint("Erro ao buscar dispositivos: $e");
    }
  }

  void _imprimir() async {
    if (_selectedDevice == null) {
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text("Selecione uma impressora primeiro.", style: TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    HapticFeedback.lightImpact();
    setState(() => _isPrinting = true);

    try {
      bool? isConnected = await bluetooth.isConnected;
      if (!isConnected!) {
        await bluetooth.connect(_selectedDevice!);
      }

      // --- COMANDOS ESC/POS ---
      bluetooth.printNewLine();
      bluetooth.printCustom("STOX - ALGODAO", 2, 1); // Nome da empresa/App
      bluetooth.printCustom(widget.itemData['ItemName'] ?? "ITEM", 1, 1);
      bluetooth.printNewLine();
      
      String codigo = widget.itemData['ItemCode'] ?? "000";
      bluetooth.printQRcode(codigo, 150, 150, 1);
      
      bluetooth.printNewLine();
      bluetooth.printLeftRight("COD: $codigo", "DEP: ${widget.deposito}", 1);
      bluetooth.printNewLine();
      bluetooth.printNewLine();
      bluetooth.printNewLine();
      
      await bluetooth.disconnect();
      
      if (mounted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.print, color: Colors.white),
                SizedBox(width: 8),
                Text("Impressão enviada com sucesso!", style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        HapticFeedback.vibrate();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text("Erro de impressão: $e", style: const TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPrinting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Impressão de Etiqueta"),
      ),
      body: Column(
        children: [
          _buildDeviceSelector(),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(child: _buildVisualEtiqueta()),
              ),
            ),
          ),
          _buildPrintButton(),
        ],
      ),
    );
  }

  Widget _buildDeviceSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.print_rounded, color: Theme.of(context).primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<BluetoothDevice>(
                isExpanded: true,
                hint: const Text("Selecione a Impressora"),
                value: _selectedDevice,
                items: _devices.map((device) {
                  return DropdownMenuItem(
                    value: device,
                    child: Text(device.name ?? "Dispositivo Desconhecido"),
                  );
                }).toList(),
                onChanged: (device) {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedDevice = device);
                },
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            color: Theme.of(context).primaryColor,
            onPressed: () {
              HapticFeedback.lightImpact();
              _getBluetoothDevices();
            },
          )
        ],
      ),
    );
  }

  Widget _buildPrintButton() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))
        ],
      ),
      child: ElevatedButton(
        onPressed: _isPrinting ? null : _imprimir,
        child: _isPrinting 
            ? const SizedBox(
                height: 24, 
                width: 24, 
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.print, size: 20),
                  SizedBox(width: 10),
                  Text("IMPRIMIR ETIQUETA"),
                ],
              ),
      ),
    );
  }

  Widget _buildVisualEtiqueta() {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 15, offset: Offset(0, 8))
        ],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "STOX AGRO", 
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.bold)
          ),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),
          Text(
            widget.itemData['ItemName'] ?? '', 
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), 
            textAlign: TextAlign.center
          ),
          const SizedBox(height: 24),
          BarcodeWidget(
            barcode: Barcode.code128(),
            data: widget.itemData['ItemCode'] ?? '000',
            width: 200,
            height: 80,
            drawText: false,
          ),
          const SizedBox(height: 12),
          Text(
            widget.itemData['ItemCode'] ?? '', 
            style: const TextStyle(letterSpacing: 2, fontWeight: FontWeight.w600, fontSize: 16)
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "DEPÓSITO: ${widget.deposito}", 
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)
              ),
              Text(
                "VER. 1.0", 
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500)
              ),
            ],
          ),
        ],
      ),
    );
  }
}