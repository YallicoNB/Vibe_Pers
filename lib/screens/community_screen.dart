import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import '../core/demo_store.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key, required this.store, required this.isActive});
  final DemoStore store;
  final bool isActive; // NUEVO

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  late TutorialCoachMark tutorialCoachMark;

  final GlobalKey _communityInfoKey = GlobalKey();
  final GlobalKey _leadersKey = GlobalKey();
  final GlobalKey _noticesKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.isActive) { // SOLO SI ESTÁ ACTIVA AL INICIAR
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkTutorial());
    }
  }

  // NUEVO: ESCUCHA CUANDO CAMBIAS DE PESTAÑA
  @override
  void didUpdateWidget(covariant CommunityScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkTutorial());
    }
  }

  Future<void> _checkTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenTutorial = prefs.getBool('tut_community') ?? false;

    if (!hasSeenTutorial && mounted) {
      _showTutorialDialog(prefs);
    }
  }

  void _showTutorialDialog(SharedPreferences prefs) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('¡Bienvenido a tu Comunidad!'),
        content: const Text(
            '¿Deseas un recorrido interactivo para ver cómo funciona esta sección?'),
        actions: [
          TextButton(
            onPressed: () {
              prefs.setBool('tut_community', true);
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
      colorShadow: const Color(0xFF126E64), // Color de Vibe Pers
      textSkip: "Omitir",
      paddingFocus: 10,
      opacityShadow: 0.9, // Subimos la opacidad para que el texto contraste mucho mejor
      onFinish: () {
        prefs.setBool('tut_community', true);
      },
      onClickTarget: (target) {
        if (target.identify == "notices") {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Simulando apertura de avisos comunitarios...')),
          );
        }
        // ESTO SOLUCIONA EL PROBLEMA: Avanza al tocar la zona iluminada
        tutorialCoachMark.next();
      },
      onSkip: () {
        prefs.setBool('tut_community', true);
        return true;
      },
    )..show(context: context);
  }

  List<TargetFocus> _createTargets() {
    return [
      TargetFocus(
        identify: "communityInfo",
        keyTarget: _communityInfoKey,
        shape: ShapeLightFocus.RRect, // <--- CLAVE: Usa rectángulo en lugar de círculo
        radius: 12, // Bordes redondeados iguales a los de tu Card
        alignSkip: Alignment.topRight,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) => const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Tu Junta Vecinal",
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Text(
                  "Aquí verás los datos de tu zona. Solo los vecinos de este sector pueden ver esta pantalla.\n\n(Toca la zona iluminada para continuar)",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          )
        ],
      ),
      TargetFocus(
        identify: "leaders",
        keyTarget: _leadersKey,
        shape: ShapeLightFocus.RRect, // <--- Rectángulo
        radius: 12,
        alignSkip: Alignment.topRight,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) => const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Liderazgo",
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Text(
                  "Identifica rápidamente a los líderes vecinales y grupos de apoyo autorizados.",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          )
        ],
      ),
      TargetFocus(
        identify: "notices",
        keyTarget: _noticesKey,
        shape: ShapeLightFocus.RRect, // <--- Rectángulo
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
                  "Interactúa (Toca aquí)",
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Text(
                  "Toca esta tarjeta iluminada para simular cómo se abre un aviso y terminar el tutorial.",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          )
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final neighbors = widget.store.communityPeople.toList();
    final leaders = neighbors.where((n) => n.isLeader).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
      children: [
        Text(
          'Mi comunidad',
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Card(
          key: _communityInfoKey, // Llave enlazada al tutorial
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.store.community.name,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(widget.store.community.area),
                const SizedBox(height: 10),
                Text(
                  widget.store.authenticatedNeighbor == null
                      ? 'Comunidad ficticia para probar el prototipo.'
                      : 'Comunidad delimitada por vecinos; no es una división oficial.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Liderazgo vecinal',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (leaders.isEmpty)
          Card(
            key: _leadersKey, // Llave enlazada al tutorial
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Tu comunidad aún no tiene líder. Organicen una convocatoria vecinal y soliciten autorización municipal.',
              ),
            ),
          )
        else
          ...leaders.map(
                (n) => Card(
              key: _leadersKey, // Llave enlazada al tutorial
              child: ListTile(
                leading: const CircleAvatar(child: Text('🦆')),
                title: Text(n.name),
                subtitle: const Text(
                  'Líder vecinal de prueba · No representa una autorización real',
                ),
                trailing: const Icon(Icons.verified_outlined),
              ),
            ),
          ),
        const SizedBox(height: 18),
        Text(
          'Vecinos',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        ...neighbors.map(
              (n) => Card(
            child: ListTile(
              leading: CircleAvatar(child: Text(n.avatar)),
              title: Text(n.name),
              subtitle: Text(
                n.supportRole ?? (n.isLeader ? 'Líder de prueba' : 'Vecino'),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Card(
          key: _noticesKey, // Llave enlazada al tutorial
          child: const ListTile(
            leading: Icon(Icons.campaign_outlined),
            title: Text('Avisos comunitarios'),
            subtitle: Text(
              'Los avisos de líderes estarán disponibles al conectar el servidor.',
            ),
          ),
        ),
      ],
    );
  }
}