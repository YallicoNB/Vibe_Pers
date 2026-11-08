import 'package:latlong2/latlong.dart';

class DemoEmergencyArea {
  const DemoEmergencyArea(this.name, this.center);
  final String name;
  final LatLng center;
  List<String> get streetReferences => switch (name) {
    'Chaclacayo' => const [
      'Av. Nicolás Ayllón',
      'Av. Alfonso Ugarte',
      'Av. Los Girasoles',
    ],
    'Lurigancho-Chosica' => const [
      'Carretera Central',
      'Av. 28 de Julio',
      'Jr. Callao',
    ],
    _ => const [
      'Av. Nicolás Ayllón',
      'Av. Separadora Industrial',
      'Av. Metropolitana',
    ],
  };
  List<LatLng> get route => [
    LatLng(center.latitude - 0.002, center.longitude - 0.0015),
    LatLng(center.latitude - 0.001, center.longitude - 0.0004),
    LatLng(center.latitude + 0.0002, center.longitude + 0.0004),
    LatLng(center.latitude + 0.0014, center.longitude + 0.0012),
  ];
  LatLng get safePoint => route.last;
}

const demoAreas = [
  DemoEmergencyArea('Chaclacayo', LatLng(-11.976, -76.767)),
  DemoEmergencyArea('Lurigancho-Chosica', LatLng(-11.938, -76.696)),
  DemoEmergencyArea('Ate', LatLng(-12.029, -76.919)),
];

DemoEmergencyArea closestDemoArea(LatLng position) {
  final distance = Distance();
  return demoAreas.reduce(
    (a, b) =>
        distance(a.center, position) <= distance(b.center, position) ? a : b,
  );
}

List<DemoEmergencyArea> orderedDemoAreas(DemoEmergencyArea first) => [
  first,
  ...demoAreas.where((area) => area.name != first.name),
];
