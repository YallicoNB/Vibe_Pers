import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/demo_emergency.dart';
import '../core/risk_map_documents.dart';

const _sigridUrl = 'https://sigrid.cenepred.gob.pe/sigridv3/';

class EvacuationDocuments extends StatelessWidget {
  const EvacuationDocuments({super.key, required this.currentArea});
  final DemoEmergencyArea currentArea;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Documentos · plan de riesgo',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 4),
      const Text(
        'Mapas de rutas de evacuación y zonas seguras, disponibles sin internet. Consulta la zona que corresponda a tu ubicación.',
      ),
      const SizedBox(height: 12),
      for (final area in orderedDemoAreas(currentArea)) ...[
        Text(
          area.name == currentArea.name
              ? '${area.name} · tu distrito'
              : area.name,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        for (final document in riskMapDocuments.where(
          (document) => document.district == area.name,
        ))
          Card(
            child: ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: Text('Zona ${document.zone}'),
              subtitle: const Text('Rutas y zonas seguras · PDF sin internet'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => EvacuationPdfScreen(document: document),
                ),
              ),
            ),
          ),
        const SizedBox(height: 12),
      ],
    ],
  );
}

class EvacuationPdfScreen extends StatefulWidget {
  const EvacuationPdfScreen({super.key, required this.document});
  final RiskMapDocument document;

  @override
  State<EvacuationPdfScreen> createState() => _EvacuationPdfScreenState();
}

class _EvacuationPdfScreenState extends State<EvacuationPdfScreen> {
  late final PdfController controller;

  @override
  void initState() {
    super.initState();
    controller = PdfController(
      document: PdfDocument.openAsset(widget.document.assetPath),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('${widget.document.district} · ${widget.document.zone}'),
    ),
    body: Column(
      children: [
        const MaterialBanner(
          content: Text(
            'Consulta la fecha y los créditos dentro del mapa. Antes de evacuar, sigue las indicaciones de las autoridades locales.',
          ),
          actions: [SizedBox.shrink()],
        ),
        Expanded(child: PdfView(controller: controller)),
        TextButton.icon(
          onPressed: () => launchUrl(
            Uri.parse(_sigridUrl),
            mode: LaunchMode.externalApplication,
          ),
          icon: const Icon(Icons.open_in_new),
          label: const Text('Portal de referencia: SIGRID / CENEPRED'),
        ),
      ],
    ),
  );
}
