import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/demo_store.dart';
import '../core/models.dart';
import 'community_screen.dart';
import 'emergency_screen.dart';
import 'extras_screen.dart';
import 'map_screen.dart';
import 'market_screen.dart';
import 'publish_screen.dart';

class DemoBanner extends StatelessWidget {
  const DemoBanner({super.key, required this.remote});
  final bool remote;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    color: const Color(0xFFFFE9B4),
    child: Text(
      remote
          ? 'DATOS FICTICIOS DE EJEMPLO · MERCADO REAL CUANDO PUBLIQUES · SOS DEMO'
          : 'DATOS FICTICIOS · DEMOSTRACIÓN LOCAL',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Color(0xFF805C16),
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.store, this.onProfileChanged});
  final DemoStore store;
  final Future<void> Function()? onProfileChanged;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int tab = 0;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) {
      if (!widget.store.introSeen) {
        return _IntroScreens(onDone: widget.store.finishIntro);
      }
      final store = widget.store;
      final pages = [
        CommunityScreen(store: store, isActive: tab == 0), // NUEVO
        MapScreen(key: ValueKey(store.mapTarget?.id), store: store),
        MarketScreen(
          store: store,
          onShowOnMap: (Listing listing) {
            store.mapTarget = listing;
            setState(() => tab = 1);
          },
        ),
        EmergencyScreen(store: store, isActive: tab == 3), // NUEVO
      ];
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Vibe Pers',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          actions: [
            if (store.authenticatedNeighbor == null)
              IconButton(
                tooltip: 'Cambiar vecino de prueba',
                icon: const Icon(Icons.account_circle_outlined),
                onPressed: () => _showProfile(context, store),
              ),
          ],
        ),
        drawer: Drawer(
          child: SafeArea(
            child: ListView(
              children: [
                UserAccountsDrawerHeader(
                  accountName: Text(store.currentUser.name),
                  accountEmail: Text(store.community.name),
                  currentAccountPicture: CircleAvatar(
                    child: Text(store.currentUser.avatar),
                  ),
                ),
                for (final item in const [
                  (Icons.person_outline, 'Mi perfil'),
                  (Icons.inventory_2_outlined, 'Mis publicaciones'),
                  (Icons.volunteer_activism_outlined, 'Mis ayudas'),
                  (Icons.notifications_outlined, 'Mis alertas'),
                  (Icons.settings_outlined, 'Ajustes'),
                  (Icons.swap_horiz_outlined, 'Cambiar de junta'),
                  (Icons.offline_bolt_outlined, 'Información offline'),
                  (Icons.info_outline, 'Acerca de'),
                ])
                  ListTile(
                    leading: Icon(item.$1),
                    title: Text(item.$2),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ExtraScreen(
                            title: item.$2,
                            store: store,
                            onProfileChanged: widget.onProfileChanged,
                          ),
                        ),
                      );
                    },
                  ),
                if (store.authenticatedNeighbor != null)
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text('Cerrar sesión'),
                    onTap: () async {
                      Navigator.pop(context);
                      await Supabase.instance.client.auth.signOut();
                    },
                  ),
              ],
            ),
          ),
        ),
        body: Column(
          children: [
            DemoBanner(remote: store.authenticatedNeighbor != null),
            Expanded(
              child: IndexedStack(index: tab, children: pages),
            ),
          ],
        ),
        floatingActionButton: tab != 2
            ? null
            : FloatingActionButton.extended(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PublishScreen(store: store),
                  ),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Publicar'),
              ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (i) {
            setState(() => tab = i);
            if (store.authenticatedNeighbor != null && (i == 1 || i == 2)) {
              store.refreshRemote();
            }
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.groups_outlined),
              label: 'Comunidad',
            ),
            NavigationDestination(
              icon: Icon(Icons.map_outlined),
              label: 'Mapa',
            ),
            NavigationDestination(
              icon: Icon(Icons.storefront_outlined),
              label: 'Mercado',
            ),
            NavigationDestination(
              icon: Icon(Icons.health_and_safety_outlined),
              label: 'Emergencias',
            ),
          ],
        ),
      );
    },
  );

  void _showProfile(BuildContext context, DemoStore store) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vecino de prueba',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Cambia de cuenta ficticia para probar recomendaciones y respuestas. No existe inicio de sesión real.',
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 320,
                  child: ListView(
                    children: DemoStore.neighbors
                        .map(
                          (n) => ListTile(
                            leading: CircleAvatar(child: Text(n.avatar)),
                            title: Text('${n.avatar}  ${n.name}'),
                            subtitle: Text(
                              DemoStore.communities
                                  .firstWhere((c) => c.id == n.communityId)
                                  .name,
                            ),
                            selected: n.id == store.currentUserId,
                            trailing: n.id == store.currentUserId
                                ? const Icon(Icons.check)
                                : null,
                            onTap: () {
                              store.switchUser(n.id);
                              Navigator.pop(sheetContext);
                            },
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _IntroScreens extends StatefulWidget {
  const _IntroScreens({required this.onDone});
  final VoidCallback onDone;
  @override
  State<_IntroScreens> createState() => _TutorialState();
}

class _TutorialState extends State<_IntroScreens> {
  int page = 0;
  final items = const [
    (
      Icons.place_outlined,
      'Todo más cerca',
      'Explora servicios y productos de tu comunidad y mira los vistos buenos de otros vecinos.',
    ),
    (
      Icons.volunteer_activism_outlined,
      'Ayuda sin dinero',
      'Pide, ofrece o intercambia apoyo solidario con personas de tu junta vecinal.',
    ),
    (
      Icons.health_and_safety_outlined,
      'Preparados juntos',
      'Consulta recursos de emergencia. El SOS de esta versión es una simulación local.',
    ),
  ];
  @override
  Widget build(BuildContext context) {
    final item = items[page];
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: widget.onDone,
                  child: const Text('Omitir'),
                ),
              ),
              const Spacer(),
              CircleAvatar(
                radius: 68,
                backgroundColor: const Color(0xFFFFE9B4),
                child: Icon(item.$1, size: 72, color: const Color(0xFF126E64)),
              ),
              const SizedBox(height: 34),
              Text(
                item.$2,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              Text(
                item.$3,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const Spacer(),
              Text('${page + 1} / ${items.length}'),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (page == items.length - 1) {
                      widget.onDone();
                    } else {
                      setState(() => page++);
                    }
                  },
                  child: Text(
                    page == items.length - 1 ? 'Empezar' : 'Siguiente',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
