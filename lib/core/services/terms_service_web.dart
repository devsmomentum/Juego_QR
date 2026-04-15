import 'dart:html' as html;
import 'package:flutter/foundation.dart';
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
          debugPrint('Intentando descargar términos de: $name');
          fileBytes = await storage.download(name);
          if (fileBytes != null && fileBytes.isNotEmpty) break;
        } catch (e) {
          debugPrint('Fallo descarga para $name: $e');
        }
      }

      if (fileBytes != null && fileBytes.isNotEmpty) {
        // Crear un Blob y una URL de objeto para enmascarar Supabase
        final blob = html.Blob([fileBytes], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);

        // Abrir bajo el dominio de la app (blob:https://...)
        html.window.open(url, '_blank');
      } else {
        throw Exception('No se pudo encontrar o descargar el archivo de términos.');
      }
    } catch (e) {
      throw Exception('Error en TermsServiceWeb: $e');
    }
  }
}

// Factoría para exportar la implementación correcta
TermsService getTermsService() => TermsServiceImpl();
