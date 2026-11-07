import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/demo_store.dart';
import '../core/demo_emergency.dart';
import '../core/models.dart';
import 'detail_screens.dart';
import 'market_screen.dart';
import 'evacuation_documents.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key, required this.store});
  final DemoStore store;
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  bool mapMode = true;
  bool emergencyMode = false;
  final MapController mapController = MapController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _locate();
    });
  }

  @override
  void dispose() {
    mapController.dispose();
    super.dispose();
  }

  String category = 'Todas';
  Position? position;
  String? locationMessage;
  Future<void> _locate() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Activa la ubicación del dispositivo.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception(
          'Permiso de ubicación denegado. Puedes seguir usando tu comunidad manualmente.',
        );
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 12),
        ),
      );
      if (mounted) {
        setState(() {
          position = p;
          locationMessage = 'Distancias aproximadas desde tu ubicación.';
        });
      }
      if (mapMode) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) mapController.move(LatLng(p.latitude, p.longitude), 15);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => locationMessage = e.toString().replaceFirst('Exception: ', ''),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final area =
        widget.store.selectedEmergencyArea ??
        closestDemoArea(
          position == null
              ? LatLng(widget.store.community.lat, widget.store.community.lng)
              : LatLng(position!.latitude, position!.longitude),
        );
    final all = widget.store.localListings;
    final safeResources = widget.store.remoteResources
        .where(
          (r) =>
              r['lat'] != null &&
              r['lng'] != null &&
              r['is_demo'] == false &&
              r['verified_at'] != null,
        )
        .toList();
    final categories = [
      'Todas',
      ...{for (final l in all) l.category},
    ];
    final listings = all
        .where((l) => category == 'Todas' || l.category == category)
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
      children: [
        Text(
          'Cerca de mí',
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          emergencyMode
              ? 'SIMULACIÓN de evacuación para ${area.name}. Ruta y punto inventados.'
              : widget.store.authenticatedNeighbor != null
              ? 'Negocios publicados por vecinos de ${widget.store.community.name}.'
              : 'Puntos ficticios de ${widget.store.community.name}. No son direcciones reales.',
        ),
        const SizedBox(height: 12),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
              value: false,
              label: Text('Negocios'),
              icon: Icon(Icons.storefront),
            ),
            ButtonSegment(
              value: true,
              label: Text('Emergencia'),
              icon: Icon(Icons.warning_amber),
            ),
          ],
          selected: {emergencyMode},
          onSelectionChanged: (v) {
            setState(() {
              emergencyMode = v.first;
              mapMode = true;
            });
            if (v.first) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) mapController.move(area.center, 14);
              });
            }
          },
        ),
        if (emergencyMode)
          DropdownButton<DemoEmergencyArea>(
            value: area,
            isExpanded: true,
            items: [
              for (final option in demoAreas)
                DropdownMenuItem(
                  value: option,
                  child: Text('Distrito: ${option.name}'),
                ),
            ],
            onChanged: (option) {
              widget.store.selectEmergencyArea(option);
              if (option != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) mapController.move(option.center, 14);
                });
              }
            },
          ),
        if (emergencyMode)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'DEMO: La ruta y el punto del mapa son inventados. NO los uses para evacuar. Los teléfonos oficiales sí están disponibles sin internet.',
              style: TextStyle(color: Color(0xFF9E2929)),
            ),
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _locate,
              icon: const Icon(Icons.my_location),
              label: const Text('Usar mi ubicación'),
            ),
            OutlinedButton.icon(
              onPressed: () => setState(() => mapMode = !mapMode),
              icon: Icon(mapMode ? Icons.list : Icons.map_outlined),
              label: Text(mapMode ? 'Ver lista' : 'Ver mapa'),
            ),
          ],
        ),
        if (locationMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(locationMessage!),
          ),
        if (!emergencyMode)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: categories
                  .map(
                    (c) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(c),
                        selected: c == category,
                        onSelected: (_) => setState(() => category = c),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        const SizedBox(height: 12),
        if (mapMode)
          _RealMap(
            listings: emergencyMode ? const [] : listings,
            community: widget.store.community,
            target: widget.store.mapTarget,
            demoArea: area,
            emergencyMode: emergencyMode,
            resources: safeResources,
            boundary: widget.store.communityBoundary,
            position: position,
            controller: mapController,
            onTap: (l) => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    ListingDetailScreen(store: widget.store, listing: l),
              ),
            ),
          )
        else if (!emergencyMode)
          ...listings.map(
            (l) => Column(
              children: [
                ListingCard(store: widget.store, listing: l),
                if (position != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${(Geolocator.distanceBetween(position!.latitude, position!.longitude, l.lat, l.lng) / 1000).toStringAsFixed(1)} km aprox. · ${l.isRemote ? 'publicación vecinal' : 'punto ficticio'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
        if (emergencyMode) ...[
          const SizedBox(height: 12),
          Text(
            'Calles y avenidas de referencia: ${area.streetReferences.join(' → ')}',
          ),
          const Text('Los nombres no validan el trazado rojo de la demo.'),
          const SizedBox(height: 12),
          EvacuationDocuments(currentArea: area),
        ],
        if (!emergencyMode && listings.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('Sin resultados.'),
            ),
          ),
      ],
    );
  }
}

class _RealMap extends StatelessWidget {
  const _RealMap({
    required this.listings,
    required this.community,
    required this.target,
    required this.demoArea,
    required this.emergencyMode,
    required this.resources,
    required this.boundary,
    required this.position,
    required this.controller,
    required this.onTap,
  });

  final List<Listing> listings;
  final Community community;
  final Listing? target;
  final DemoEmergencyArea demoArea;
  final bool emergencyMode;
  final List<Map<String, dynamic>> resources;
  final List<LatLng> boundary;
  final Position? position;
  final MapController controller;
  final ValueChanged<Listing> onTap;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: SizedBox(
      height: 390,
      child: Stack(
        children: [
          if (emergencyMode)
            const Positioned.fill(child: ColoredBox(color: Color(0xFFFFE9E9))),
          FlutterMap(
            mapController: controller,
            options: MapOptions(
              initialCenter: target == null
                  ? LatLng(community.lat, community.lng)
                  : LatLng(target!.lat, target!.lng),
              initialZoom: 15,
              minZoom: 4,
              maxZoom: 18,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.vibepers.prototype',
              ),
              if (boundary.length >= 4)
                PolygonLayer(
                  polygons: [
                    Polygon(
                      points: boundary,
                      color: emergencyMode
                          ? const Color(0x22CE3030)
                          : const Color(0x22157A6E),
                      borderColor: emergencyMode
                          ? const Color(0xFFB42323)
                          : const Color(0xFF126E64),
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
              if (emergencyMode)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: demoArea.route,
                      color: const Color(0xFFC92B2B),
                      strokeWidth: 5,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (emergencyMode)
                    for (var i = 0; i < demoArea.streetReferences.length; i++)
                      Marker(
                        point: demoArea.route[i],
                        width: 152,
                        height: 38,
                        child: IgnorePointer(
                          child: Card(
                            color: Colors.white,
                            child: Center(
                              child: Text(
                                demoArea.streetReferences[i],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ),
                        ),
                      ),
                  if (emergencyMode)
                    Marker(
                      point: demoArea.safePoint,
                      width: 58,
                      height: 58,
                      child: const Tooltip(
                        message: 'Punto ficticio; NO usar para evacuar',
                        child: CircleAvatar(
                          backgroundColor: Color(0xFFC92B2B),
                          child: Icon(Icons.shield, color: Colors.white),
                        ),
                      ),
                    ),
                  if (emergencyMode)
                    for (final r in resources)
                      Marker(
                        point: LatLng(
                          (r['lat'] as num).toDouble(),
                          (r['lng'] as num).toDouble(),
                        ),
                        width: 48,
                        height: 48,
                        child: IconButton(
                          tooltip: r['title'] as String,
                          icon: const Icon(
                            Icons.shield_outlined,
                            color: Color(0xFFC72D2D),
                            size: 38,
                          ),
                          onPressed: () => showModalBottomSheet<void>(
                            context: context,
                            builder: (ctx) => SafeArea(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      r['title'] as String,
                                      style: Theme.of(ctx).textTheme.titleLarge,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(r['details'] as String),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Fuente: ${r['verification_source'] as String? ?? 'Sin fuente'}',
                                    ),
                                    Text(
                                      'Verificado: ${r['verified_at'] as String? ?? 'Sin fecha'}',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  if (!emergencyMode)
                    for (final listing in listings)
                      Marker(
                        point: LatLng(listing.lat, listing.lng),
                        width: 52,
                        height: 52,
                        child: IconButton.filled(
                          tooltip: listing.title,
                          onPressed: () => onTap(listing),
                          icon: Icon(
                            listing.kind == 'Servicio'
                                ? Icons.handyman
                                : Icons.shopping_bag,
                          ),
                        ),
                      ),
                  if (position != null)
                    Marker(
                      point: LatLng(position!.latitude, position!.longitude),
                      width: 28,
                      height: 28,
                      child: const Tooltip(
                        message: 'Tu ubicación aproximada',
                        child: CircleAvatar(
                          backgroundColor: Color(0xFF1677D2),
                          child: Icon(
                            Icons.person_pin_circle,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (emergencyMode)
            const Positioned.fill(
              child: IgnorePointer(child: ColoredBox(color: Color(0x11D32F2F))),
            ),
          if (emergencyMode)
            const Positioned(
              left: 8,
              top: 8,
              child: Chip(
                label: Text(
                  'SIMULACIÓN · NO EVACUAR AQUÍ',
                  style: TextStyle(
                    color: Color(0xFFB42323),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          Positioned(
            right: 8,
            bottom: 8,
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              child: InkWell(
                onTap: () => launchUrl(
                  Uri.parse('https://www.openstreetmap.org/copyright'),
                  mode: LaunchMode.externalApplication,
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Text(
                    '© OpenStreetMap contributors',
                    style: TextStyle(fontSize: 10),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
