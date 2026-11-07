import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/demo_emergency.dart';

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
        'Mapas PDF incluidos en la app. Se abren sin internet. Son esquemas inventados para esta demo.',
      ),
      const SizedBox(height: 8),
      for (final area in orderedDemoAreas(currentArea))
        Card(
          child: ListTile(
            leading: const Icon(Icons.picture_as_pdf_outlined),
            title: Text('Mapa de ejemplo: ${area.name}'),
            subtitle: Text(
              area.name == currentArea.name
                  ? 'Tu distrito · primera opción · disponible sin internet'
                  : 'Distrito cercano · disponible sin internet',
            ),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => EvacuationPdfScreen(area: area),
              ),
            ),
          ),
        ),
    ],
  );
}

class EvacuationPdfScreen extends StatefulWidget {
  const EvacuationPdfScreen({super.key, required this.area});
  final DemoEmergencyArea area;

  @override
  State<EvacuationPdfScreen> createState() => _EvacuationPdfScreenState();
}

class _EvacuationPdfScreenState extends State<EvacuationPdfScreen> {
  late final PdfController controller;

  @override
  void initState() {
    super.initState();
    controller = PdfController(
      document: PdfDocument.openAsset(widget.area.pdfAsset),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Mapa PDF · ${widget.area.name}')),
    body: Column(
      children: [
        const MaterialBanner(
          content: Text(
            'SIMULACIÓN. Ruta y punto seguro inventados. No usar para evacuar.',
          ),
          actions: [SizedBox.shrink()],
        ),
        Expanded(child: PdfView(controller: controller)),
        TextButton.icon(
          onPressed: () => launchUrl(
            Uri.parse(widget.area.sourceUrl),
            mode: LaunchMode.externalApplication,
          ),
          icon: const Icon(Icons.open_in_new),
          label: Text('Consultar fuente pública: ${widget.area.sourceTitle}'),
        ),
      ],
    ),
  );
}
