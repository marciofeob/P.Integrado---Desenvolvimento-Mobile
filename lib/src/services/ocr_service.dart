import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter/material.dart';

class OcrService {
  static final ImagePicker _picker = ImagePicker();

  static Future<Map<String, String>?> lerAnotacaoDaCamera() async {
    try {
      // 1. Tira a foto
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (image == null) return null;

      // 2. Abre a tela de recorte
      CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: image.path,
        aspectRatio: const CropAspectRatio(ratioX: 4, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Recorte o Texto LIDO',
            toolbarColor: Colors.black,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.ratio16x9,
            lockAspectRatio: false,
            hideBottomControls: true,
          ),
          IOSUiSettings(
            title: 'Ajustar Área',
          ),
        ],
      );

      // Usuário cancelou o recorte
      if (croppedFile == null) return null;

      // 3. ML Kit processa a imagem recortada
      final inputImage    = InputImage.fromFilePath(croppedFile.path);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText =
          await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      final textoBruto = recognizedText.text.trim();
      final partes     = textoBruto.split(RegExp(r'\s+'));

      String itemCode  = '';
      String quantidade = '';

      if (partes.isNotEmpty) {
        if (partes.length > 1) {
          final ultimaParte = partes.last.replaceAll(',', '.');
          if (RegExp(r'^\d+(\.\d+)?$').hasMatch(ultimaParte)) {
            quantidade = ultimaParte;
            partes.removeLast();
            itemCode = partes.join(' ');
          } else {
            itemCode = partes.join(' ');
          }
        } else {
          itemCode = partes[0];
        }
      }

      return {'itemCode': itemCode, 'quantidade': quantidade};
    } catch (e) {
      debugPrint('Erro no OCR: $e');
      return null;
    }
  }

  /// Extrai texto de uma imagem sem recorte — uso genérico.
  static Future<String?> extractText({required ImageSource source}) async {
    final image = await _picker.pickImage(source: source);
    if (image == null) return null;
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final recognizedText = await textRecognizer
        .processImage(InputImage.fromFilePath(image.path));
    await textRecognizer.close();
    return recognizedText.text;
  }
}