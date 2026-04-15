import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'terms_service_interface.dart';

class TermsServiceImpl implements TermsService {
  @override
  Future<void> launchTerms(String baseUrl, String anonKey) async {
    try {
      final fileNames = [
        'Terminos_y_Condiciones_Maphunter (1).pdf',
        'Terminos_y_Condiciones_Maphunter.pdf'
      ];
      
      Uint8List? fileBytes;
      final storage = Supabase.instance.client.storage.from('documents');
      
      for (final name in fileNames) {
        try {
          debugPrint('Intentando descargar con SDK (Mobile): $name');
          fileBytes = await storage.download(name);
          if (fileBytes != null && fileBytes.isNotEmpty) break;
        } catch (e) {
          debugPrint('Fallo descarga SDK Mobile para $name: $e');
        }
      }

      if (fileBytes != null && fileBytes.isNotEmpty) {
        // Mostrar PDF en visor nativo
        await Printing.layoutPdf(
          onLayout: (_) => fileBytes!,
          name: 'Terminos_y_Condiciones_Maphunter.pdf',
        );
      } else {
        throw Exception('No se pudo encontrar o descargar el archivo de términos.');
      }
    } catch (e) {
      throw Exception('Error al abrir términos nativos: $e');
    }
  }
}

TermsService getTermsService() => TermsServiceImpl();
