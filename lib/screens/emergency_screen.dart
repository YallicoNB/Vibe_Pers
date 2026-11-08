import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import '../core/demo_store.dart';
import '../core/demo_emergency.dart';
import 'evacuation_documents.dart';

class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key, required this.store, required this.isActive});
  final DemoStore store;
  final bool isActive; // NUEVO

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  final sosKey = GlobalKey();
  final _contactsKey = GlobalKey();
  late TutorialCoachMark tutorialCoachMark;

  final pointers = <int>{};
  Timer? holdTimer;
  Timer? tickTimer;
  bool holding = false;
  DateTime? expiresAt;
  Position? position;

  @override
  void initState() {
    super.initState();
    Geolocator.getLastKnownPosition().then((p) {
      if (mounted && p != null) setState(() => position = p);
    }).catchError((Object _) {});

    if (widget.isActive) { // SOLO SI ESTÁ ACTIVA AL INICIAR
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkTutorial());
    }
  }

  @override
  void dispose() {
    holdTimer?.cancel();
    tickTimer?.cancel();
    super.dispose();
  }

  // NUEVO: ESCUCHA CUANDO CAMBIAS DE PESTAÑA
  @override
  void didUpdateWidget(covariant EmergencyScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkTutorial());
    }
  }

  Future<void> _checkTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenTutorial = prefs.getBool('tut_emergency') ?? false;

    if (!hasSeenTutorial && mounted) {
      _showTutorialDialog(prefs);
    }
  }

  void _showTutorialDialog(SharedPreferences prefs) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Prevención y Alertas'),
        content: const Text(
            '¿Deseas ver un recorrido rápido sobre cómo emitir una alerta SOS y ver recursos?'),
        actions: [
          TextButton(
            onPressed: () {
              prefs.setBool('tut_emergency', true);
              Navigator.pop(context);
            },
            child: const Text('Omitir'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _initTutorial(prefs);
            },
            child: const Text('Empezar'),
          ),
        ],
      ),
    );
  }

  void _initTutorial(SharedPreferences prefs) {
    tutorialCoachMark = TutorialCoachMark(
      targets: _createTargets(),
      colorShadow: const Color(0xFF901B1B),
      textSkip: "Omitir",
      paddingFocus: 10,
      opacityShadow: 0.9,
      onFinish: () {
        prefs.setBool('tut_emergency', true);
      },
      onClickTarget: (target) {
        // SOLUCIÓN: Si tocamos la luz del botón SOS, hacemos scroll hacia abajo
        if (target.identify == "sosButton") {
          if (_contactsKey.currentContext != null) {
            Scrollable.ensureVisible(
              _contactsKey.currentContext!,
              alignment: 0.5, // El 0.5 asegura que el elemento quede justo en el centro de la pantalla
              duration: const Duration(milliseconds: 200), // Pequeña animación para que se vea fluido
            );
          }
        }
        tutorialCoachMark.next();
      },
      onSkip: () {
        prefs.setBool('tut_emergency', true);
        return true;
      },
    )..show(context: context);
  }

  List<TargetFocus> _createTargets() {
    return [
      TargetFocus(
        identify: "sosButton",
        keyTarget: sosKey,
        shape: ShapeLightFocus.Circle,
        radius: 10,
        alignSkip: Alignment.topRight,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) => const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Botón SOS Protegido",
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Text(
                  "Para evitar alertas falsas (regla de MVP), debes presionar con DOS DEDOS simultáneamente durante 2 SEGUNDOS continuos.\n\n(Toca la luz para continuar)",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          )
        ],
      ),
      TargetFocus(
        identify: "contacts",
        keyTarget: _contactsKey,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        alignSkip: Alignment.topRight,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) => const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Recursos Oficiales",
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Text(
                  "Aquí encontrarás números de emergencia pre-cargados. Al presionarlos, abrirán directamente el marcador de tu celular.\n\n(Toca la luz para finalizar el tutorial)",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          )
        ],
      ),
    ];
  }

  // --- LÓGICA DE EMERGENCIA ORIGINAL ---

  bool get active => expiresAt != null && DateTime.now().isBefore(expiresAt!);
  bool _insideSos(Offset globalPosition) {
    final box = sosKey.currentContext?.findRenderObject();
    if (box is! RenderBox) return false;
    final local = box.globalToLocal(globalPosition);
    return (Offset.zero & box.size).contains(local);
  }

  void _pointerDown(PointerDownEvent e) {
    if (!_insideSos(e.position)) return;
    pointers.add(e.pointer);
    if (pointers.length == 2 && !active) {
      setState(() => holding = true);
      holdTimer?.cancel();
      holdTimer = Timer(const Duration(seconds: 2), () {
        if (mounted && pointers.length >= 2) _activate();
      });
    }
  }

  void _pointerUp(PointerEvent e) {
    pointers.remove(e.pointer);
    if (pointers.length < 2) {
      holdTimer?.cancel();
      if (mounted) setState(() => holding = false);
    }
  }

  void _activate() {
    setState(() {
      holding = false;
      expiresAt = DateTime.now().add(const Duration(minutes: 15));
    });
    tickTimer?.cancel();
    tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (!active) {
        tickTimer?.cancel();
        setState(() => expiresAt = null);
      } else {
        setState(() {});
      }
    });
  }

  Future<void> _accessibleActivate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Activar simulación SOS'),
        content: const Text(
          'Esta alerta solo aparece en tu dispositivo. No llegará a vecinos ni autoridades. Para una emergencia real, llama a los servicios oficiales.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Activar demo'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) _activate();
  }

  Future<void> _call(String number) async {
    if (!await launchUrl(Uri(scheme: 'tel', path: number)) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el marcador.')),
      );
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
    final minutes = active
        ? expiresAt!.difference(DateTime.now()).inSeconds
        : 0;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _pointerDown,
      onPointerUp: _pointerUp,
      onPointerCancel: _pointerUp,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
        children: [
          Text(
            'Emergencias',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Card(
            color: Color(0xFFFFF1E8),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'El SOS aún no envía avisos a otros dispositivos. Esta pantalla permite probar el gesto y el tiempo de vigencia; para pedir auxilio real usa los teléfonos oficiales.',
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (active)
            Card(
              color: const Color(0xFFFFE5E1),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 48,
                      color: Color(0xFFAF3D2E),
                    ),
                    const Text(
                      'SIMULACIÓN SOS ACTIVA',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'Termina en ${minutes ~/ 60}:${(minutes % 60).toString().padLeft(2, '0')}',
                    ),
                    const Text('Ningún vecino recibió esta alerta.'),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton(
                          onPressed: () => setState(() {
                            expiresAt = null;
                            tickTimer?.cancel();
                          }),
                          child: const Text('Finalizar'),
                        ),
                        const SizedBox(width: 10),
                        FilledButton.tonal(
                          onPressed: () => setState(
                                () => expiresAt = expiresAt!.add(
                              const Duration(minutes: 15),
                            ),
                          ),
                          child: const Text('Extender +15 min'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          else ...[
            const Text(
              'Coloca dos dedos sobre SOS durante 2 segundos continuos.',
            ),
            const SizedBox(height: 10),
            Center(
              child: Semantics(
                label: 'SOS de demostración. Mantén dos dedos durante dos segundos.',
                child: AnimatedContainer(
                  key: sosKey, // La llave del botón SOS (ya estaba, se reutiliza para el tutorial)
                  duration: const Duration(milliseconds: 200),
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: holding
                        ? const Color(0xFFBC4B3F)
                        : const Color(0xFFE36050),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33B94739),
                        blurRadius: 18,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.sos, color: Colors.white, size: 58),
                      Text(
                        holding ? 'Mantén 2 segundos' : 'SOS DEMO',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (holding)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),
                            duration: const Duration(seconds: 2),
                            builder: (context, value, _) => SizedBox(
                              width: 70,
                              child: LinearProgressIndicator(
                                value: value,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: _accessibleActivate,
                child: const Text('Activar sin gesto multitáctil'),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Text(
            'Llamadas oficiales',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const Text(
            'El botón abre el marcador. La llamada depende de tu red telefónica.',
          ),
          const SizedBox(height: 6),

          // --- AQUÍ APLICAMOS LA LLAVE A LOS CONTACTOS ---
          Container(
            key: _contactsKey,
            child: Column(
              children: [
                _contact('Policía Nacional', '105', Icons.local_police_outlined),
                _contact('Bomberos', '116', Icons.fire_truck_outlined),
                _contact('SAMU', '106', Icons.medical_services_outlined),
              ],
            ),
          ),

          TextButton(
            onPressed: () => launchUrl(
              Uri.parse('https://www.gob.pe/547-telefonos-de-emergencia'),
              mode: LaunchMode.externalApplication,
            ),
            child: const Text('Fuente oficial: gob.pe/547'),
          ),
          const SizedBox(height: 12),
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
            onChanged: (option) =>
                setState(() => widget.store.selectEmergencyArea(option)),
          ),
          Text(
            'Plan de evacuación de ejemplo: ${area.name}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SIMULACIÓN · NO USAR EN UNA EMERGENCIA REAL',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFB42323),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '1. Identifica el peligro y consulta las instrucciones de Defensa Civil.',
                  ),
                  Text(
                    '2. En la demo, sigue la línea roja del mapa hasta el punto ficticio señalado.',
                  ),
                  Text(
                    '3. Practica un recuento de vecinos y acuerda cómo ayudar a quienes necesiten apoyo.',
                  ),
                  Text(
                    '4. Ante una emergencia real, usa los teléfonos oficiales y las rutas vigentes de la autoridad.',
                  ),
                ],
              ),
            ),
          ),
          EvacuationDocuments(currentArea: area),
          const SizedBox(height: 16),
          Text(
            'Recursos comunitarios de prueba',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const Card(
            child: ListTile(
              leading: Icon(Icons.groups_outlined),
              title: Text('Brigada vecinal de ejemplo'),
              subtitle: Text('Grupo ficticio. No ofrece respuesta real.'),
            ),
          ),
          const Card(
            child: ListTile(
              leading: Icon(Icons.place_outlined),
              title: Text('Punto seguro de ejemplo'),
              subtitle: Text(
                'Ubicación ficticia. No usar como ruta de evacuación real.',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contact(String name, String number, IconData icon) => Card(
    child: ListTile(
      leading: Icon(icon, color: const Color(0xFF126E64)),
      title: Text(name),
      subtitle: Text(number),
      trailing: const Icon(Icons.call_outlined),
      onTap: () => _call(number),
    ),
  );
}
