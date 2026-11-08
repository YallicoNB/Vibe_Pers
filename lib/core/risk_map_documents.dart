import 'demo_emergency.dart';

class RiskMapDocument {
  const RiskMapDocument(this.district, this.zone, this.assetPath);

  final String district;
  final String zone;
  final String assetPath;
}

const riskMapDocuments = [
  RiskMapDocument(
    'Chaclacayo',
    'El Cuadro',
    'assets/evacuation/chaclacayo_el_cuadro.pdf',
  ),
  RiskMapDocument(
    'Chaclacayo',
    'Santa Inés',
    'assets/evacuation/chaclacayo_santa_ines.pdf',
  ),
  RiskMapDocument(
    'Chaclacayo',
    'Valle Hermoso',
    'assets/evacuation/chaclacayo_valle_hermoso.pdf',
  ),
  RiskMapDocument(
    'Lurigancho-Chosica',
    'La Libertad',
    'assets/evacuation/chosica_la_libertad.pdf',
  ),
  RiskMapDocument(
    'Lurigancho-Chosica',
    'El Pedregal',
    'assets/evacuation/chosica_el_pedregal.pdf',
  ),
  RiskMapDocument(
    'Lurigancho-Chosica',
    'Quirio',
    'assets/evacuation/chosica_quirio.pdf',
  ),
  RiskMapDocument(
    'Ate',
    'Estrella Andina',
    'assets/evacuation/ate_estrella_andina.pdf',
  ),
  RiskMapDocument(
    'Ate',
    'Gloria Chica',
    'assets/evacuation/ate_gloria_chica.pdf',
  ),
  RiskMapDocument('Ate', 'San Juan', 'assets/evacuation/ate_san_juan.pdf'),
];

List<RiskMapDocument> orderedRiskMapDocuments(DemoEmergencyArea first) => [
  for (final area in orderedDemoAreas(first))
    ...riskMapDocuments.where((document) => document.district == area.name),
];
