import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/demo_store.dart';
import 'market_screen.dart';
import 'announcement_tile.dart';
import 'zone_picker_screen.dart';

class ExtraScreen extends StatelessWidget {
  const ExtraScreen({
    super.key,
    required this.title,
    required this.store,
    this.onProfileChanged,
  });
  final String title;
  final DemoStore store;
  final Future<void> Function()? onProfileChanged;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) {
      final content = switch (title) {
        'Mi perfil' => _profile(),
        'Mis publicaciones' => _listings(),
        'Mis ayudas' => _helps(),
        'Mis alertas' => _announcements(),
        'Ajustes' => _settings(context),
        'Cambiar de junta' => _changeCommunity(context),
        'Información offline' => _message(
          Icons.offline_bolt_outlined,
          'Datos guardados en este dispositivo',
          'Los avisos ya descargados pueden consultarse sin internet. Publicar avisos y cambiar grupos requiere conexión. El mapa base necesita internet o teselas vistas anteriormente.',
        ),
        _ => _message(
          Icons.info_outline,
          'MiBarrio',
          'Prototipo comunitario para Android e iOS. Los datos de ejemplo son ficticios.',
        ),
      };
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(16), children: content),
        ),
      );
    },
  );

  List<Widget> _announcements() => [
    const Text('Avisos y alertas de tu junta vecinal'),
    const SizedBox(height: 12),
    if (store.communityAnnouncements.isEmpty)
      const Card(child: ListTile(title: Text('Aún no hay avisos'))),
    for (final announcement in store.communityAnnouncements)
      AnnouncementTile(store: store, announcement: announcement),
  ];

  List<Widget> _changeCommunity(BuildContext context) => [
    const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Tu junta actual no cambia al perder internet. El cambio solo ocurre si seleccionas otra comunidad y confirmas.',
        ),
      ),
    ),
    if (store.authenticatedNeighbor != null)
      FilledButton.icon(
        onPressed: () async {
          final selection = await Navigator.push<ZoneSelection>(
            context,
            MaterialPageRoute(builder: (_) => const ZonePickerScreen()),
          );
          if (selection == null || !context.mounted) return;
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Cambiar de junta'),
              content: const Text(
                'Cambiarás a la comunidad seleccionada. Tus publicaciones anteriores permanecerán en la junta original.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Confirmar cambio'),
                ),
              ],
            ),
          );
          if (confirmed != true || !context.mounted) return;
          try {
            if (selection.existingId != null) {
              await Supabase.instance.client.rpc(
                'change_my_community',
                params: {'p_community_id': selection.existingId},
              );
            } else {
              await Supabase.instance.client.rpc(
                'create_and_join_community',
                params: {
                  'p_name': selection.name,
                  'p_boundary': selection.geoJson,
                },
              );
            }
            await onProfileChanged?.call();
            if (context.mounted) Navigator.pop(context);
          } catch (_) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'No se pudo cambiar de junta. Comprueba la conexión.',
                  ),
                ),
              );
            }
          }
        },
        icon: const Icon(Icons.swap_horiz),
        label: const Text('Elegir o dibujar otra comunidad'),
      ),
  ];

  List<Widget> _profile() => [
    Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(radius: 30, child: Text(store.currentUser.avatar)),
            const SizedBox(height: 12),
            Text(
              store.currentUser.name,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            Text(store.community.name),
            const SizedBox(height: 8),
            Text(
              store.authenticatedNeighbor == null
                  ? 'Perfil ficticio para probar la interfaz.'
                  : 'Cuenta vinculada a Supabase. El mercado y SOS continúan en modo de prueba.',
            ),
          ],
        ),
      ),
    ),
  ];

  List<Widget> _listings() {
    final mine = store.localListings
        .where((listing) => listing.ownerId == store.currentUserId)
        .toList();
    return [
      if (mine.isEmpty)
        const Padding(
          padding: EdgeInsets.all(20),
          child: Text('Aún no tienes publicaciones locales.'),
        ),
      ...mine.map((listing) => ListingCard(store: store, listing: listing)),
    ];
  }

  List<Widget> _helps() {
    final mine = store.localHelp
        .where((post) => post.authorId == store.currentUserId)
        .toList();
    return [
      if (mine.isEmpty)
        const Padding(
          padding: EdgeInsets.all(20),
          child: Text('Aún no tienes solicitudes u ofertas locales.'),
        ),
      ...mine.map((post) => HelpCard(store: store, post: post)),
    ];
  }

  List<Widget> _settings(BuildContext context) => [
    Card(
      child: ListTile(
        leading: const Icon(Icons.school_outlined),
        title: const Text('Volver a ver la introducción'),
        subtitle: const Text('Muestra las tres pantallas iniciales.'),
        onTap: () {
          store.resetIntro();
          Navigator.pop(context);
        },
      ),
    ),
    const Card(
      child: ListTile(
        leading: Icon(Icons.location_on_outlined),
        title: Text('Ubicación'),
        subtitle: Text('Solo se solicita cuando pulsas «Usar mi ubicación».'),
      ),
    ),
  ];

  List<Widget> _message(IconData icon, String heading, String message) => [
    Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(icon, size: 46, color: const Color(0xFF126E64)),
            const SizedBox(height: 12),
            Text(
              heading,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    ),
  ];
}
