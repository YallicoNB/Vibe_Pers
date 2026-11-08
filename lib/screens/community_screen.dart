import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import '../core/demo_store.dart';
import '../core/models.dart';
import '../core/community_updates.dart';
import 'announcement_composer_screen.dart';
import 'announcement_tile.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({
    super.key,
    required this.store,
    required this.isActive,
  });
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
    if (widget.isActive) {
      // SOLO SI ESTÁ ACTIVA AL INICIAR
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
          '¿Deseas un recorrido interactivo para ver cómo funciona esta sección?',
        ),
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
      colorShadow: const Color(0xFF126E64), // Color de MiBarrio
      textSkip: "Omitir",
      paddingFocus: 10,
      opacityShadow:
          0.9, // Subimos la opacidad para que el texto contraste mucho mejor
      onFinish: () {
        prefs.setBool('tut_community', true);
      },
      onClickTarget: (target) {
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
        shape: ShapeLightFocus
            .RRect, // <--- CLAVE: Usa rectángulo en lugar de círculo
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
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  "Aquí verás los datos de tu zona. Solo los vecinos de este sector pueden ver esta pantalla.\n\n(Toca la zona iluminada para continuar)",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),
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
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  "Identifica rápidamente a los líderes vecinales y grupos de apoyo autorizados.",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),
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
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  "Aquí aparecen los avisos y alertas publicados por el líder de tu junta.",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    ];
  }

  Future<void> _assignGroup(Neighbor neighbor) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('Grupo de ${neighbor.name}'),
              subtitle: const Text('Solo un grupo a la vez.'),
            ),
            for (final entry in <MapEntry<String, String>>[
              const MapEntry('VECINOS', 'Vecinos'),
              ...communityGroupLabels.entries,
            ])
              ListTile(
                title: Text(entry.value),
                trailing:
                    (widget.store.groupOf(neighbor) ?? 'VECINOS') == entry.key
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(sheetContext, entry.key),
              ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    try {
      await widget.store.assignGroup(
        neighbor,
        choice == 'VECINOS' ? null : choice,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo cambiar el grupo. Comprueba tu rol y la conexión.',
            ),
          ),
        );
      }
    }
  }

  Widget _neighborTile(Neighbor neighbor) => Card(
    child: ListTile(
      leading: CircleAvatar(child: Text(neighbor.avatar)),
      title: Text(neighbor.name),
      subtitle: Text(
        neighbor.id.startsWith('demo-')
            ? 'Perfil ficticio de demostración'
            : neighbor.supportRole ??
                  (neighbor.isLeader ? 'Líder vecinal' : 'Vecino'),
      ),
      trailing: widget.store.currentUser.isLeader && !neighbor.isLeader
          ? const Icon(Icons.edit_outlined)
          : null,
      onTap: widget.store.currentUser.isLeader && !neighbor.isLeader
          ? () => _assignGroup(neighbor)
          : null,
    ),
  );

  Widget _groupSection(
    BuildContext context,
    String title,
    List<Neighbor> people,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 16),
      Text(
        title,
        style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      if (people.isEmpty)
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text('Aún no hay integrantes.'),
        ),
      for (final neighbor in people) _neighborTile(neighbor),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final neighbors = widget.store.communityPeople.toList();
    final leaders = neighbors.where((n) => n.isLeader).toList();
    final regular = neighbors
        .where((n) => !n.isLeader && widget.store.groupOf(n) == null)
        .toList();
    final announcements = widget.store.communityAnnouncements;

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
          key: _communityInfoKey,
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
        Column(
          key: _leadersKey,
          children: [
            if (leaders.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Tu comunidad aún no tiene líder asignado.',
                  ),
                ),
              )
            else
              for (final neighbor in leaders) _neighborTile(neighbor),
          ],
        ),
        const SizedBox(height: 18),
        Column(
          key: _noticesKey,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Avisos comunitarios',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (widget.store.currentUser.isLeader)
              FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        AnnouncementComposerScreen(store: widget.store),
                  ),
                ),
                icon: const Icon(Icons.add_alert_outlined),
                label: const Text('Crear aviso'),
              ),
            if (announcements.isEmpty)
              const Card(
                child: ListTile(
                  leading: Icon(Icons.campaign_outlined),
                  title: Text('Aún no hay avisos'),
                  subtitle: Text(
                    'Los avisos publicados por el líder aparecerán aquí.',
                  ),
                ),
              ),
            for (final announcement in announcements)
              AnnouncementTile(store: widget.store, announcement: announcement),
          ],
        ),
        _groupSection(context, 'Vecinos', regular),
        for (final entry in communityGroupLabels.entries)
          _groupSection(
            context,
            entry.value,
            neighbors
                .where(
                  (n) => !n.isLeader && widget.store.groupOf(n) == entry.key,
                )
                .toList(),
          ),
      ],
    );
  }
}
