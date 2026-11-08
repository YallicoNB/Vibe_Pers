import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import '../core/demo_store.dart';
import '../core/models.dart';
import 'detail_screens.dart';

class MarketScreen extends StatefulWidget {
  // AÑADIDO: isActive en el constructor
  const MarketScreen({super.key, required this.store, required this.isActive, this.onShowOnMap});
  final DemoStore store;
  final bool isActive;
  final ValueChanged<Listing>? onShowOnMap;
  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  // LLAVES PARA EL TUTORIAL
  final GlobalKey _segmentedControlKey = GlobalKey();
  final GlobalKey _searchBarKey = GlobalKey();
  late TutorialCoachMark tutorialCoachMark;

  int section = 0;
  String query = '';

  @override
  void initState() {
    super.initState();
    // SOLO SE LANZA SI LA PESTAÑA NACE ACTIVA
    if (widget.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkTutorial());
    }
  }

  // AÑADIDO: ESCUCHA CUANDO EL USUARIO CAMBIA A ESTA PESTAÑA
  @override
  void didUpdateWidget(covariant MarketScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkTutorial());
    }
  }

  // --- LÓGICA DEL TUTORIAL INTERACTIVO ---
  Future<void> _checkTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenTutorial = prefs.getBool('tut_market') ?? false;

    if (!hasSeenTutorial && mounted) {
      _showTutorialDialog(prefs);
    }
  }

  void _showTutorialDialog(SharedPreferences prefs) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Economía Solidaria'),
        content: const Text(
            '¿Deseas ver un recorrido rápido sobre cómo comprar o intercambiar favores con tus vecinos?'),
        actions: [
          TextButton(
            onPressed: () {
              prefs.setBool('tut_market', true);
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
      colorShadow: const Color(0xFF126E64),
      textSkip: "Omitir",
      paddingFocus: 10,
      opacityShadow: 0.9,
      onFinish: () {
        prefs.setBool('tut_market', true);
      },
      onClickTarget: (target) {
        if (target.identify == "segmentedControl") {
          if (_searchBarKey.currentContext != null) {
            Scrollable.ensureVisible(
              _searchBarKey.currentContext!,
              alignment: 0.5,
              duration: const Duration(milliseconds: 200),
            );
          }
        }
        tutorialCoachMark.next();
      },
      onSkip: () {
        prefs.setBool('tut_market', true);
        return true;
      },
    )..show(context: context);
  }

  List<TargetFocus> _createTargets() {
    return [
      TargetFocus(
        identify: "segmentedControl",
        keyTarget: _segmentedControlKey,
        shape: ShapeLightFocus.RRect,
        radius: 20,
        alignSkip: Alignment.topRight,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) => const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Compra o Ayuda",
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Text(
                  "Usa 'Mercado' para ver productos de tu zona, y 'Ayuda' para ofrecer o pedir favores vecinales que no involucren dinero.\n\n(Toca la luz para continuar)",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          )
        ],
      ),
      TargetFocus(
        identify: "searchBar",
        keyTarget: _searchBarKey,
        shape: ShapeLightFocus.RRect,
        radius: 30, // Bordes del TextField
        alignSkip: Alignment.topRight,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) => const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Búsqueda Local",
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Text(
                  "Filtra rápidamente por categorías, productos o tipos de ayuda.\n\n(Toca la luz para finalizar)",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          )
        ],
      ),
    ];
  }
  // --- FIN LÓGICA TUTORIAL ---

  @override
  Widget build(BuildContext context) {
    final listings = widget.store.localListings
        .where(
          (l) => '${l.title} ${l.category} ${l.description}'
          .toLowerCase()
          .contains(query.toLowerCase()),
    )
        .toList();
    final help = widget.store.localHelp
        .where(
          (h) => '${h.title} ${h.mode} ${h.description}'.toLowerCase().contains(
        query.toLowerCase(),
      ),
    )
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
      children: [
        Text(
          'Mercado y solidaridad',
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),

        // --- LLAVE DEL TUTORIAL AQUÍ ---
        SegmentedButton<int>(
          key: _segmentedControlKey,
          segments: const [
            ButtonSegment(
              value: 0,
              label: Text('Mercado'),
              icon: Icon(Icons.storefront_outlined),
            ),
            ButtonSegment(
              value: 1,
              label: Text('Ayuda'),
              icon: Icon(Icons.volunteer_activism_outlined),
            ),
          ],
          selected: {section},
          onSelectionChanged: (value) => setState(() => section = value.first),
        ),

        const SizedBox(height: 14),

        // --- LLAVE DEL TUTORIAL AQUÍ ---
        TextField(
          key: _searchBarKey,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Buscar en mi comunidad',
          ),
          onChanged: (v) => setState(() => query = v),
        ),

        const SizedBox(height: 12),
        if (section == 0) ...[
          if (listings.isEmpty) const _EmptyResult(),
          ...listings.map(
                (l) => ListingCard(
              store: widget.store,
              listing: l,
              onShowOnMap: widget.onShowOnMap,
            ),
          ),
        ] else ...[
          if (help.isEmpty) const _EmptyResult(),
          ...help.map((h) => HelpCard(store: widget.store, post: h)),
        ],
      ],
    );
  }
}

class _EmptyResult extends StatelessWidget {
  const _EmptyResult();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(24),
    child: Center(child: Text('No hay resultados en esta comunidad.')),
  );
}

class ListingCard extends StatelessWidget {
  const ListingCard({
    super.key,
    required this.store,
    required this.listing,
    this.onShowOnMap,
  });
  final DemoStore store;
  final Listing listing;
  final ValueChanged<Listing>? onShowOnMap;
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ListingDetailScreen(
            store: store,
            listing: listing,
            onShowOnMap: onShowOnMap,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: const Color(0xFFE6F2EC),
              child: Icon(
                listing.kind == 'Servicio'
                    ? Icons.handyman_outlined
                    : Icons.shopping_bag_outlined,
                color: const Color(0xFF126E64),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    listing.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '${listing.category} · ${listing.zone}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (listing.kind == 'Servicio')
                    Text(
                      '👍 ${listing.voters.length} vistos buenos',
                      style: const TextStyle(color: Color(0xFF126E64)),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'S/ ${listing.price.toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    ),
  );
}

class HelpCard extends StatelessWidget {
  const HelpCard({super.key, required this.store, required this.post});
  final DemoStore store;
  final HelpPost post;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFFFE9B4),
        child: Icon(
          post.direction == 'Necesito'
              ? Icons.pan_tool_alt_outlined
              : Icons.favorite_outline,
          color: const Color(0xFF805C16),
        ),
      ),
      title: Text(
        post.title,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${post.direction} · ${post.mode} · ${post.status.replaceAll('_', ' ')}',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => HelpDetailScreen(store: store, post: post),
        ),
      ),
    ),
  );
}