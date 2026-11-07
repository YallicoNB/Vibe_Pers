import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class PointPickerScreen extends StatefulWidget {
  const PointPickerScreen({super.key, required this.center});
  final LatLng center;
  @override
  State<PointPickerScreen> createState() => _PointPickerScreenState();
}

class _PointPickerScreenState extends State<PointPickerScreen> {
  final controller = MapController();
  LatLng? selected;
  String? message;

  Future<void> locate() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Mueve el mapa para elegir el punto.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Mueve el mapa para elegir el punto.');
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 12),
        ),
      );
      if (mounted) controller.move(LatLng(p.latitude, p.longitude), 16);
    } catch (e) {
      if (mounted) {
        setState(() => message = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ubicación del negocio')),
    body: Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            'Toca el punto donde aparecerá tu negocio. Si trabajas desde casa, elige un punto público aproximado.',
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              FlutterMap(
                mapController: controller,
                options: MapOptions(
                  initialCenter: widget.center,
                  initialZoom: 15,
                  onTap: (_, p) => setState(() => selected = p),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.vibepers.prototype',
                  ),
                  MarkerLayer(
                    markers: [
                      if (selected != null)
                        Marker(
                          point: selected!,
                          width: 44,
                          height: 44,
                          child: const Icon(
                            Icons.place,
                            color: Colors.red,
                            size: 40,
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
              TextButton.icon(
                onPressed: locate,
                icon: const Icon(Icons.my_location),
                label: const Text('Centrar en mi ubicación'),
              ),
              if (message != null) Text(message!),
              FilledButton(
                onPressed: selected == null
                    ? null
                    : () => Navigator.pop(context, selected),
                child: const Text('Usar este punto'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
