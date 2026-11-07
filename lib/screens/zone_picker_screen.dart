import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ZoneSelection {
  const ZoneSelection.create(this.name, this.points) : existingId = null;
  const ZoneSelection.join(this.existingId) : name = null, points = const [];
  final String? existingId;
  final String? name;
  final List<LatLng> points;
  Map<String, dynamic>? get geoJson => existingId != null
      ? null
      : {
          'type': 'Polygon',
          'coordinates': [
            [
              for (final p in points) [p.longitude, p.latitude],
              [points.first.longitude, points.first.latitude],
            ],
          ],
        };
}

class ZonePickerScreen extends StatefulWidget {
  const ZonePickerScreen({super.key, this.joinOnly = false});
  final bool joinOnly;
  @override
  State<ZonePickerScreen> createState() => _ZonePickerScreenState();
}

class _ZonePickerScreenState extends State<ZonePickerScreen> {
  final map = MapController();
  final name = TextEditingController();
  final points = <LatLng>[];
  late final Future<List<Map<String, dynamic>>> areas = _load();
  bool joinMode = false;
  String? chosenId;
  String? chosenName;
  String? message;

  @override
  void initState() {
    super.initState();
    joinMode = widget.joinOnly;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _locate();
    });
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final rows = await Supabase.instance.client.rpc('list_community_areas');
    return List<Map<String, dynamic>>.from(rows as List);
  }

  List<LatLng> _boundary(Map<String, dynamic> row) {
    try {
      final data =
          jsonDecode(row['boundary_geojson'] as String) as Map<String, dynamic>;
      return ((data['coordinates'] as List).first as List).map((item) {
        final p = item as List;
        return LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble());
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _locate() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Activa la ubicación o mueve el mapa.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Puedes mover el mapa sin GPS.');
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 12),
        ),
      );
      if (mounted) map.move(LatLng(p.latitude, p.longitude), 15);
    } catch (e) {
      if (mounted) {
        setState(() => message = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  void _finish() {
    if (joinMode) {
      if (chosenId == null) {
        setState(() => message = 'Selecciona una comunidad en el mapa.');
        return;
      }
      Navigator.pop(context, ZoneSelection.join(chosenId));
    } else {
      if (name.text.trim().length < 3 || points.length < 3) {
        setState(() => message = 'Pon un nombre y marca al menos tres puntos.');
        return;
      }
      Navigator.pop(
        context,
        ZoneSelection.create(name.text.trim(), List.of(points)),
      );
    }
  }

  @override
  void dispose() {
    map.dispose();
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Define tu comunidad')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: widget.joinOnly
              ? const Text('Selecciona otra comunidad en el mapa')
              : SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      label: Text('Crear zona'),
                      icon: Icon(Icons.draw),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text('Unirme'),
                      icon: Icon(Icons.groups),
                    ),
                  ],
                  selected: {joinMode},
                  onSelectionChanged: (v) => setState(() {
                    joinMode = v.first;
                    message = null;
                  }),
                ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            joinMode ? 'Toca el nombre de una zona vecinal existente.' : 'Toca el mapa para dibujar tu zona. Evita incluir tu domicilio exacto.',
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              FlutterMap(
                mapController: map,
                options: MapOptions(
                  initialCenter: const LatLng(-11.938, -76.696),
                  initialZoom: 14,
                  onTap: (_, p) {
                    if (!joinMode) {
                      setState(() {
                        points.add(p);
                        message = null;
                      });
                    }
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.vibepers.prototype',
                  ),
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: areas,
                    builder: (_, snap) {
                      return PolygonLayer(
                        polygons: [
                          for (final row
                              in snap.data ?? const <Map<String, dynamic>>[])
                            if (_boundary(row).length >= 4)
                              Polygon(
                                points: _boundary(row),
                                color: const Color(0x33157A6E),
                                borderColor: const Color(0xFF157A6E),
                                borderStrokeWidth: 2,
                              ),
                          if (points.length >= 3)
                            Polygon(
                              points: points,
                              color: const Color(0x443E9D85),
                              borderColor: const Color(0xFF126E64),
                              borderStrokeWidth: 3,
                            ),
                        ],
                      );
                    },
                  ),
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: areas,
                    builder: (_, snap) {
                      return MarkerLayer(
                        markers: [
                          for (final row
                              in snap.data ?? const <Map<String, dynamic>>[])
                            if (row['center_lat'] != null &&
                                row['center_lng'] != null)
                              Marker(
                                point: LatLng(
                                  (row['center_lat'] as num).toDouble(),
                                  (row['center_lng'] as num).toDouble(),
                                ),
                                width: 130,
                                height: 44,
                                child: FilledButton(
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.all(4),
                                    backgroundColor: chosenId == row['id']
                                        ? Colors.teal
                                        : Colors.blueGrey,
                                  ),
                                  onPressed: joinMode
                                      ? () => setState(() {
                                          chosenId = row['id'] as String;
                                          chosenName = row['name'] as String;
                                        })
                                      : null,
                                  child: Text(
                                    row['name'] as String,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                ),
                              ),
                        ],
                      );
                    },
                  ),
                  MarkerLayer(
                    markers: [
                      for (var i = 0; i < points.length; i++)
                        Marker(
                          point: points[i],
                          width: 25,
                          height: 25,
                          child: CircleAvatar(
                            backgroundColor: Colors.teal,
                            child: Text(
                              (i + 1).toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const Positioned(
                right: 8,
                bottom: 8,
                child: ColoredBox(
                  color: Colors.white,
                  child: Text(
                    '© OpenStreetMap contributors',
                    style: TextStyle(fontSize: 10),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!joinMode) ...[
                TextField(
                  controller: name,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de la comunidad',
                  ),
                ),
                Wrap(
                  spacing: 4,
                  children: [
                    TextButton.icon(
                      onPressed: _locate,
                      icon: const Icon(Icons.my_location),
                      label: const Text('Mi ubicación'),
                    ),
                    TextButton(
                      onPressed: points.isEmpty
                          ? null
                          : () => setState(() => points.removeLast()),
                      child: const Text('Deshacer punto'),
                    ),
                    TextButton(
                      onPressed: points.isEmpty
                          ? null
                          : () => setState(points.clear),
                      child: const Text('Borrar'),
                    ),
                  ],
                ),
              ] else
                Text(
                  chosenName == null
                      ? 'Ninguna comunidad seleccionada'
                      : 'Comunidad: ${chosenName!}',
                ),
              if (message != null)
                Text(
                  message!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              FilledButton(
                onPressed: _finish,
                child: Text(
                  joinMode ? 'Unirme a esta comunidad' : 'Confirmar mi zona',
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
