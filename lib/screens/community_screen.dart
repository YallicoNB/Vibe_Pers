import 'package:flutter/material.dart';

import '../core/demo_store.dart';

class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key, required this.store});
  final DemoStore store;
  @override
  Widget build(BuildContext context) {
    final neighbors = store.communityPeople.toList();
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
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  store.community.name,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(store.community.area),
                const SizedBox(height: 10),
                Text(
                  store.authenticatedNeighbor == null
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
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Tu comunidad aún no tiene líder. Organicen una convocatoria vecinal y soliciten autorización municipal.',
              ),
            ),
          )
        else
          ...leaders.map(
            (n) => Card(
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
        const Card(
          child: ListTile(
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
