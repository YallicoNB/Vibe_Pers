import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/demo_store.dart';
import '../core/models.dart';

class ListingDetailScreen extends StatefulWidget {
  const ListingDetailScreen({
    super.key,
    required this.store,
    required this.listing,
    this.onShowOnMap,
  });
  final DemoStore store;
  final Listing listing;
  final ValueChanged<Listing>? onShowOnMap;
  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final l = widget.listing;
    final owner = widget.store.person(l.ownerId);
    final canVote =
        l.kind == 'Servicio' && l.ownerId != widget.store.currentUserId;
    final voted = l.voters.contains(widget.store.currentUserId);
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          if (l.photoUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.network(
                l.photoUrl!,
                height: 210,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox(
                  height: 160,
                  child: Center(child: Icon(Icons.broken_image_outlined)),
                ),
              ),
            )
          else if (l.photoPath != null && File(l.photoPath!).existsSync())
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.file(
                File(l.photoPath!),
                height: 210,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              height: 170,
              decoration: BoxDecoration(
                color: const Color(0xFFE6F2EC),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                l.kind == 'Servicio'
                    ? Icons.handyman_outlined
                    : Icons.shopping_bag_outlined,
                size: 72,
                color: const Color(0xFF126E64),
              ),
            ),
          const SizedBox(height: 18),
          Text(
            l.title,
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text('${l.kind} · ${l.category} · ${l.zone}'),
          const SizedBox(height: 12),
          Text(
            'S/ ${l.price.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(color: const Color(0xFF126E64)),
          ),
          const SizedBox(height: 12),
          Text(l.description),
          const SizedBox(height: 18),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(child: Text(owner.avatar)),
            title: Text(owner.name),
            subtitle: Text(
              l.isRemote
                  ? 'Vecino de esta comunidad'
                  : 'Vecino de demostración',
            ),
          ),
          if (l.kind == 'Servicio') ...[
            const Divider(),
            Text(
              'Recomendado por ${l.voters.length} vecinos',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const Text(
              'Un visto bueno no certifica identidad ni calidad profesional.',
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: canVote
                  ? () async {
                      final ok = await widget.store.toggleVoteFor(l);
                      if (mounted) {
                        if (!ok) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'No se pudo guardar el visto bueno.',
                              ),
                            ),
                          );
                        }
                        setState(() {});
                      }
                    }
                  : null,
              icon: Icon(voted ? Icons.thumb_up : Icons.thumb_up_outlined),
              label: Text(voted ? 'Quitar mi visto bueno' : 'Dar visto bueno'),
            ),
            if (!canVote)
              const Text('No puedes recomendar tu propio servicio.'),
          ],
          const SizedBox(height: 12),
          if (widget.onShowOnMap != null)
            FilledButton.tonalIcon(
              onPressed: () {
                widget.onShowOnMap!(l);
                Navigator.pop(context);
              },
              icon: const Icon(Icons.map_outlined),
              label: const Text('Ver ubicación en el mapa'),
            ),
          const SizedBox(height: 12),
          if (l.whatsapp != null)
            FilledButton.icon(
              onPressed: () async {
                final phone = l.whatsapp!.replaceAll(RegExp(r'\D'), '');
                final uri = Uri.parse('https://wa.me/$phone');
                if (!await launchUrl(
                      uri,
                      mode: LaunchMode.externalApplication,
                    ) &&
                    context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No se pudo abrir WhatsApp.')),
                  );
                }
              },
              icon: const Icon(Icons.chat_outlined),
              label: const Text('Contactar por WhatsApp'),
            )
          else
            const Text('El anunciante no publicó un WhatsApp de contacto.'),
          const SizedBox(height: 12),
          Text(
            l.isRemote
                ? 'Ficha publicada por un vecino. El punto puede ser aproximado.'
                : 'Ficha de demostración local. La ubicación es aproximada y no representa una dirección real.',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class HelpDetailScreen extends StatefulWidget {
  const HelpDetailScreen({super.key, required this.store, required this.post});
  final DemoStore store;
  final HelpPost post;
  @override
  State<HelpDetailScreen> createState() => _HelpDetailScreenState();
}

class _HelpDetailScreenState extends State<HelpDetailScreen> {
  final controller = TextEditingController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    final owner = widget.store.person(p.authorId);
    final mine = p.authorId == widget.store.currentUserId;
    return Scaffold(
      appBar: AppBar(title: const Text('Ayuda sin dinero')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text(
            p.title,
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text('${p.direction} · ${p.mode} · ${p.status.replaceAll('_', ' ')}'),
          const SizedBox(height: 14),
          Text(p.description),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(child: Text(owner.avatar)),
            title: Text(owner.name),
            subtitle: const Text('Publicación ficticia · sin pagos'),
          ),
          const Divider(),
          Text(
            'Respuestas (${p.responses.length})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (p.responses.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Aún no hay respuestas.'),
            ),
          ...p.responses.map(
            (r) => Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.store.person(r.authorId).name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(r.message),
                    if (mine && p.status == 'ABIERTA')
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            widget.store.accept(p, r.id);
                            setState(() {});
                          },
                          child: const Text('Aceptar ayuda'),
                        ),
                      ),
                    if (p.acceptedResponseId == r.id)
                      const Text(
                        'Ayuda aceptada',
                        style: TextStyle(
                          color: Color(0xFF126E64),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (!mine && p.status == 'ABIERTA') ...[
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 2,
              maxLength: 300,
              decoration: const InputDecoration(labelText: 'Tu respuesta'),
            ),
            FilledButton(
              onPressed: () {
                if (widget.store.respond(p, controller.text)) {
                  controller.clear();
                  setState(() {});
                }
              },
              child: const Text('Ofrecer ayuda'),
            ),
          ],
          if (mine && !['RESUELTA', 'CANCELADA'].contains(p.status)) ...[
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () {
                widget.store.closeHelp(p, 'RESUELTA');
                setState(() {});
              },
              child: const Text('Marcar como resuelta'),
            ),
            TextButton(
              onPressed: () {
                widget.store.closeHelp(p, 'CANCELADA');
                setState(() {});
              },
              child: const Text('Cancelar publicación'),
            ),
          ],
          const SizedBox(height: 14),
          const Text(
            'Las respuestas se guardan solo en este dispositivo. Otros teléfonos aún no pueden verlas.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
