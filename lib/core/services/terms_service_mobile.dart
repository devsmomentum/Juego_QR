import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import 'terms_service_interface.dart';

class TermsServiceImpl implements TermsService {
  @override
  Future<void> launchTerms(String baseUrl, String anonKey) async {
    try {
      // Use the Edge Function as a secure proxy to hide the Storage URL
      final termsUrl = '$baseUrl/functions/v1/get-terms';

      // Download bytes privately via the proxy function with auth headers
      final response = await http.get(
        Uri.parse(termsUrl),
        headers: {
          'apikey': anonKey,
          'Authorization': 'Bearer $anonKey',
        },
      );

      if (response.statusCode == 200) {
        // Use printing package to show PDF in native viewer
        await Printing.layoutPdf(
          onLayout: (_) => response.bodyBytes,
          name: 'Terminos_y_Condiciones_Maphunter.pdf',
        );
      } else {
        throw Exception('Falló la descarga del PDF del storage: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error al abrir términos en móvil: $e');
    }
  }
}

TermsService getTermsService() => TermsServiceImpl();
