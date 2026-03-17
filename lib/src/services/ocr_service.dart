import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

/// Serviço de leitura de texto via câmera usando Google ML Kit.
///
/// Fluxo principal ([lerAnotacaoDaCamera]):
/// 1. Captura foto com a câmera
/// 2. Abre UI de recorte para o usuário isolar o texto
/// 3. Processa a imagem recortada com OCR (script latino)
/// 4. Extrai código do item e quantidade do texto reconhecido
class OcrService {
  OcrService._();

  static final _picker = ImagePicker();

  // ── OCR principal ─────────────────────────────────────────────────────────

  /// Captura, recorta e processa uma imagem da câmera.
  ///
  /// Retorna `{'itemCode': ..., 'quantidade': ...}` ou `null` se o usuário
  /// cancelar em qualquer etapa ou se ocorrer um erro.
  static Future<Map<String, String>?> lerAnotacaoDaCamera() async {
    try {
      final imagem = await _picker.pickImage(
        source:       ImageSource.camera,
        imageQuality: 85,
      );
      if (imagem == null) return null;

      final recorte = await ImageCropper().cropImage(
        sourcePath:  imagem.path,
        aspectRatio: const CropAspectRatio(ratioX: 4, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle:       'Recorte o texto',
            toolbarColor:       Colors.black,
            toolbarWidgetColor: Colors.white,
            initAspectRatio:    CropAspectRatioPreset.ratio16x9,
            lockAspectRatio:    false,
            hideBottomControls: true,
          ),
          IOSUiSettings(title: 'Ajustar área'),
        ],
      );
      if (recorte == null) return null;

      final resultado = await _reconhecerTexto(recorte.path);
      return _parsearTexto(resultado);
    } catch (e) {
      if (kDebugMode) debugPrint('OcrService.lerAnotacaoDaCamera: $e');
      return null;
    }
  }

  /// Extrai texto de uma imagem sem recorte — uso genérico.
  static Future<String?> extractText({required ImageSource source}) async {
    try {
      final imagem = await _picker.pickImage(source: source);
      if (imagem == null) return null;
      return await _reconhecerTexto(imagem.path);
    } catch (e) {
      if (kDebugMode) debugPrint('OcrService.extractText: $e');
      return null;
    }
  }

  // ── Helpers privados ──────────────────────────────────────────────────────

  /// Executa o OCR numa imagem e retorna o texto bruto.
  static Future<String> _reconhecerTexto(String caminhoArquivo) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final resultado = await recognizer
          .processImage(InputImage.fromFilePath(caminhoArquivo));
      return resultado.text.trim();
    } finally {
      await recognizer.close();
    }
  }

  /// Interpreta o texto OCR como "CÓDIGO_ITEM QUANTIDADE".
  ///
  /// Se a última palavra for numérica, é tratada como quantidade;
  /// o restante é tratado como código do item.
  static Map<String, String> _parsearTexto(String texto) {
    final partes = texto.split(RegExp(r'\s+'));
    if (partes.isEmpty || (partes.length == 1 && partes[0].isEmpty)) {
      return {'itemCode': '', 'quantidade': ''};
    }

    if (partes.length == 1) {
      return {'itemCode': partes[0], 'quantidade': ''};
    }

    final ultimaParte = partes.last.replaceAll(',', '.');
    if (RegExp(r'^\d+(\.\d+)?$').hasMatch(ultimaParte)) {
      return {
        'itemCode':   partes.sublist(0, partes.length - 1).join(' '),
        'quantidade': ultimaParte,
      };
    }

    return {'itemCode': partes.join(' '), 'quantidade': ''};
  }
}