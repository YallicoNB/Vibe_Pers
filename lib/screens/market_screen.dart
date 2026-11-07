import 'package:flutter/material.dart';

import '../core/demo_store.dart';
import '../core/models.dart';
import 'detail_screens.dart';

class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key, required this.store, this.onShowOnMap});
  final DemoStore store;
  final ValueChanged<Listing>? onShowOnMap;
  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  int section = 0;
  String query = '';
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
        SegmentedButton<int>(
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
        TextField(
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
