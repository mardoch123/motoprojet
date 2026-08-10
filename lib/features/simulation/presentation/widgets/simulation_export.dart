import 'dart:io';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:motoprojet/core/utils/app_logger.dart';
import 'package:motoprojet/features/simulation/core/simulation_engine.dart';
import 'package:motoprojet/features/simulation/presentation/simulation_provider.dart';

/// Service d'export des résultats de simulation en CSV et PDF.
class SimulationExport {
  /// Exporte un scénario en CSV et partage le fichier.
  static Future<void> exportCSV(String nomScenario, ResultatSimulation resultat) async {
    try {
      final header = ['Mois', 'Motos achetées', 'Voitures achetées', 'Motos actives',
        'Voitures actives', 'Cash disponible', 'Patrimoine total', 'Cash cumulé'];

      final rows = resultat.snapshots.map((s) => [
        'M${s.periode}',
        s.motosAchetees,
        s.voituresAchetees,
        s.motosActives,
        s.voituresActives,
        s.cashDisponible.round(),
        s.patrimoineTotal.round(),
        s.cashCumuleTotal.round(),
      ]).toList();

      final csvData = const ListToCsvConverter().convert([header, ...rows]);

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/simulation_${_sanitize(nomScenario)}.csv');
      await file.writeAsString(csvData);

      await Share.shareXFiles([XFile(file.path)], text: 'Simulation financière — $nomScenario');

      AppLogger.i('[Export] CSV exporté: ${file.path}');
    } catch (e) {
      AppLogger.e('[Export] Erreur CSV: $e');
    }
  }

  /// Exporte tous les scénarios avec résultats en PDF.
  static Future<void> exportPDF(List<ScenarioConfig> scenarios) async {
    try {
      final fmt = NumberFormat.currency(locale: 'fr_FR', symbol: ' FCFA', decimalDigits: 0);
      final pdf = pw.Document();

      for (final scenario in scenarios) {
        if (scenario.resultat == null) continue;
        final r = scenario.resultat!;
        final d = r.dernier;

        pdf.addPage(pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            // Titre
            pw.Header(level: 0, text: 'Simulation — ${scenario.nom}'),
            pw.Paragraph(text: 'Généré le ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}'),
            pw.SizedBox(height: 12),

            // Paramètres
            pw.Header(level: 1, text: 'Paramètres'),
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
              cellStyle: const pw.TextStyle(fontSize: 9),
              data: [
                ['Prix moto', fmt.format(r.parametres.prixMoto)],
                ['Prix voiture', fmt.format(r.parametres.prixVoiture)],
                ['Remboursement/jour moto', fmt.format(r.parametres.remboursementJourMoto)],
                ['Remboursement/jour voiture', fmt.format(r.parametres.remboursementJourVoiture)],
                ['Durée remboursement', '${r.parametres.dureeRemboursementMois} mois'],
                ['Taux recouvrement', '${(r.parametres.tauxRecouvrement * 100).toInt()}%'],
                ['Cash initial', fmt.format(r.parametres.cashInitial)],
                ['Durée simulation', '${r.parametres.dureeMois} mois'],
              ],
            ),
            pw.SizedBox(height: 16),

            // Résumé
            pw.Header(level: 1, text: 'Résultats au mois ${d.periode}'),
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
              cellStyle: const pw.TextStyle(fontSize: 9),
              data: [
                ['Véhicules achetés', '${d.totalVehicules} (${d.motosAchetees} motos, ${d.voituresAchetees} voitures)'],
                ['Véhicules actifs', '${d.totalActifs}'],
                ['Cash disponible', fmt.format(d.cashDisponible)],
                ['Patrimoine total', fmt.format(d.patrimoineTotal)],
              ],
            ),
            pw.SizedBox(height: 16),

            // Tableau mensuel
            pw.Header(level: 1, text: 'Détail mensuel'),
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
              cellStyle: const pw.TextStyle(fontSize: 8),
              headers: ['Mois', 'Motos', 'Voitures', 'Actifs', 'Cash', 'Patrimoine'],
              data: r.snapshots.map((s) => [
                'M${s.periode}',
                '${s.motosAchetees}',
                '${s.voituresAchetees}',
                '${s.totalActifs}',
                NumberFormat.decimalPattern('fr_FR').format(s.cashDisponible.round()),
                NumberFormat.decimalPattern('fr_FR').format(s.patrimoineTotal.round()),
              ]).toList(),
            ),
          ],
        ));
      }

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/simulation_financiere.pdf');
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles([XFile(file.path)], text: 'Simulation financière MotoProjet');

      AppLogger.i('[Export] PDF exporté: ${file.path}');
    } catch (e) {
      AppLogger.e('[Export] Erreur PDF: $e');
    }
  }

  static String _sanitize(String s) =>
      s.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_').toLowerCase();
}
