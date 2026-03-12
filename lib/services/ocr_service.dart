import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart'; // 🔥 Novo import
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter/material.dart'; // 🔥 Trocado para material.dart

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

      // 2. 🔥 NOVO: Abre a tela de recorte logo após a foto
      CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: image.path,
        aspectRatio: const CropAspectRatio(ratioX: 4, ratioY: 1), // Abre em formato retangular (tipo scanner)
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Recorte o Texto LIDO',
            toolbarColor: Colors.black,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.ratio16x9,
            lockAspectRatio: false, // Deixei falso para o usuário poder ajustar a caixa livremente
            hideBottomControls: true, // Esconde botões desnecessários
          ),
          IOSUiSettings(
            title: 'Ajustar Área',
          ),
        ],
      );

      // Se o usuário cancelar o recorte, aborta o processo
      if (croppedFile == null) return null;

      // 3. O ML Kit agora processa a imagem RECORTADA em vez da imagem original inteira
      final inputImage = InputImage.fromFilePath(croppedFile.path);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      String textoBruto = recognizedText.text.trim();
      
      // Lógica original mantida intacta
      List<String> partes = textoBruto.split(RegExp(r'\s+'));
      
      String itemCode = "";
      String quantidade = "";

      if (partes.isNotEmpty) {
        if (partes.length > 1) {
          String ultimaParte = partes.last.replaceAll(',', '.');
          if (RegExp(r'^\d+(\.\d+)?$').hasMatch(ultimaParte)) {
            quantidade = ultimaParte;
            partes.removeLast();
            itemCode = partes.join(" "); 
          } else {
            itemCode = partes.join(" ");
          }
        } else {
          itemCode = partes[0];
        }
      }

      return {
        'itemCode': itemCode,
        'quantidade': quantidade,
      };
    } catch (e) {
      debugPrint("Erro no OCR: $e");
      return null;
    }
  }

  // Mantido intacto caso você chame de outro lugar
  static Future<String?> extractText({required ImageSource source}) async {
    final image = await _picker.pickImage(source: source);
    if (image == null) return null;
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final recognizedText = await textRecognizer.processImage(InputImage.fromFilePath(image.path));
    await textRecognizer.close();
    return recognizedText.text;
  }
}