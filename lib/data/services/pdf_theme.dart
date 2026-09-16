import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/constants/vehicle_constants.dart';

/// Paleta y tipografía compartidas por los PDF de la app: fondo blanco apto
/// para impresión, con el azul de la marca como acento.
class PdfTheme {
  PdfTheme._();

  static const primary = PdfColor.fromInt(0xFF1565C0);
  static const background = PdfColor.fromInt(0xFFFFFFFF);
  static const surface = PdfColor.fromInt(0xFFF5F5F5);
  static const textPrimary = PdfColor.fromInt(0xFF212121);
  static const textSecondary = PdfColor.fromInt(0xFF757575);
  static const divider = PdfColor.fromInt(0xFFE0E0E0);

  /// Documento con Roboto (regular/bold/italic) ya configurada.
  static Future<pw.Document> createDocument({String? title}) async {
    return pw.Document(
      title: title,
      author: 'Gestor de Vehículos',
      theme: pw.ThemeData.withFont(
        base: await PdfGoogleFonts.robotoRegular(),
        bold: await PdfGoogleFonts.robotoBold(),
        italic: await PdfGoogleFonts.robotoItalic(),
      ),
    );
  }

  static PdfColor statusColor(VehicleStatus status) {
    switch (status) {
      case VehicleStatus.available:
        return const PdfColor.fromInt(0xFF4CAF50);
      case VehicleStatus.inUse:
        return const PdfColor.fromInt(0xFF2196F3);
      case VehicleStatus.inWorkshop:
        return const PdfColor.fromInt(0xFFFF9800);
      case VehicleStatus.outOfService:
        return const PdfColor.fromInt(0xFFF44336);
    }
  }

  /// Aclara [color] hacia blanco: con strength 0.15 queda un 15% del color.
  static PdfColor tint(PdfColor color, double strength) => PdfColor(
        1 - (1 - color.red) * strength,
        1 - (1 - color.green) * strength,
        1 - (1 - color.blue) * strength,
      );
}
