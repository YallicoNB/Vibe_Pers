import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'community_geometry.dart';
import 'demo_emergency.dart';

class DemoStore extends ChangeNotifier {
  DemoStore._(this._prefs);
  final SharedPreferences _prefs;
  static const communities = [
    Community(
      id: 'palmeras',
      name: 'Junta Las Palmeras',
      area: 'Zona de demostración A',
      lat: -11.9380,
      lng: -76.6960,
    ),
    Community(
      id: 'olivos',
      name: 'Junta Los Olivos',
      area: 'Zona de demostración B',
      lat: -11.9420,
      lng: -76.7010,
    ),
  ];
  static const neighbors = [
    Neighbor(
      id: 'ana',
      name: 'Ana Quispe',
      communityId: 'palmeras',
      avatar: '🦆',
    ),
    Neighbor(
      id: 'luis',
      name: 'Luis Rojas',
      communityId: 'palmeras',
      avatar: '🦆',
      isLeader: true,
    ),
    Neighbor(
      id: 'maria',
      name: 'María Salas',
      communityId: 'palmeras',
      avatar: '🦆',
      supportRole: 'Apoyo vecinal',
    ),
    Neighbor(
      id: 'pedro',
      name: 'Pedro Díaz',
      communityId: 'palmeras',
      avatar: '🦆',
    ),
    Neighbor(
      id: 'carmen',
      name: 'Carmen Vera',
      communityId: 'olivos',
      avatar: '🦆',
    ),
    Neighbor(
      id: 'jose',
      name: 'José León',
      communityId: 'olivos',
      avatar: '🦆',
    ),
  ];
  static Future<DemoStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    final store = DemoStore._(prefs);
    store.currentUserId = prefs.getString('currentUserId') ?? 'ana';
    store.introSeen = prefs.getBool('introSeen') ?? false;
    try {
      final rawListings = prefs.getString('listings');
      store.listings = rawListings == null
          ? store._seedListings()
          : (jsonDecode(rawListings) as List)
                .map(
                  (e) => Listing.fromJson(Map<String, dynamic>.from(e as Map)),
                )
                .toList();
      final rawPosts = prefs.getString('helpPosts');
      store.helpPosts = rawPosts == null
          ? store._seedHelp()
          : (jsonDecode(rawPosts) as List)
                .map(
                  (e) => HelpPost.fromJson(Map<String, dynamic>.from(e as Map)),
                )
                .toList();
    } catch (_) {
      store.listings = store._seedListings();
      store.helpPosts = store._seedHelp();
    }
    return store;
  }

  late String currentUserId;
  bool introSeen = false;
  List<Listing> listings = [];
  List<HelpPost> helpPosts = [];
  Neighbor? authenticatedNeighbor;
  Community? activeCommunity;
  List<LatLng> communityBoundary = [];
  List<Listing> remoteListings = [];
  List<Map<String, dynamic>> remoteResources = [];
  Map<String, Neighbor> remoteNeighbors = {};
  String? remoteError;
  Listing? mapTarget;
  DemoEmergencyArea? selectedEmergencyArea;
  void selectEmergencyArea(DemoEmergencyArea? area) {
    selectedEmergencyArea = area;
    notifyListeners();
  }

  bool restoreCachedProfile(String uid) {
    final raw = _prefs.getString('profile_$uid');
    if (raw == null) return false;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final c = Community(
        id: data['id'] as String,
        name: data['name'] as String,
        area: data['area'] as String,
        lat: (data['lat'] as num).toDouble(),
        lng: (data['lng'] as num).toDouble(),
      );
      final boundary = (data['boundary'] as List)
          .map(
            (v) => LatLng((v[0] as num).toDouble(), (v[1] as num).toDouble()),
          )
          .toList();
      bindProfile(uid, data['displayName'] as String, c, boundary);
      return true;
    } catch (_) {
      return false;
    }
  }

  Neighbor get currentUser =>
      authenticatedNeighbor ??
      neighbors.firstWhere((n) => n.id == currentUserId);
  Community get community =>
      activeCommunity ??
      communities.firstWhere((c) => c.id == currentUser.communityId);
  Iterable<Neighbor> get communityPeople => authenticatedNeighbor != null
      ? [...remoteNeighbors.values, ...demoNeighbors]
      : neighbors.where((n) => n.communityId == community.id);
  Neighbor person(String id) =>
      remoteNeighbors[id] ??
      demoNeighbors.where((n) => n.id == id).firstOrNull ??
      (authenticatedNeighbor?.id == id
          ? authenticatedNeighbor!
          : neighbors.firstWhere(
              (n) => n.id == id,
              orElse: () => Neighbor(
                id: id,
                name: 'Vecino',
                communityId: community.id,
                avatar: '🦆',
              ),
            ));
  bool containsPoint(double lat, double lng) =>
      authenticatedNeighbor == null ||
      (communityBoundary.length >= 3 &&
          pointInBoundary(communityBoundary, lat, lng));
  List<Listing> get localListings => authenticatedNeighbor != null
      ? (List<Listing>.of(
          [...remoteListings, ...demoListings].where(
            (l) => l.communityId == community.id && containsPoint(l.lat, l.lng),
          ),
        )..sort((a, b) => b.createdAt.compareTo(a.createdAt)))
      : (listings.where((x) => x.communityId == community.id).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt)));
  List<HelpPost> get localHelp =>
      helpPosts.where((x) => x.communityId == community.id).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  void bindProfile(
    String id,
    String name,
    Community remoteCommunity,
    List<LatLng> boundary,
  ) {
    activeCommunity = remoteCommunity;
    communityBoundary = boundary;
    authenticatedNeighbor = Neighbor(
      id: id,
      name: name,
      communityId: remoteCommunity.id,
      avatar: '🦆',
      isLeader: true,
    );
    currentUserId = id;
    remoteNeighbors = {id: authenticatedNeighbor!};
    remoteListings = [];
    remoteResources = [];
    final cachedData = _prefs.getString('community_data_${remoteCommunity.id}');
    if (cachedData != null) {
      try {
        final data = jsonDecode(cachedData) as Map<String, dynamic>;
        remoteListings = (data['listings'] as List)
            .map((e) => Listing.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        remoteResources = (data['resources'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        for (final p in data['people'] as List) {
          final row = Map<String, dynamic>.from(p as Map);
          remoteNeighbors[row['id'] as String] = Neighbor(
            id: row['id'] as String,
            name: row['display_name'] as String,
            communityId: remoteCommunity.id,
            avatar: '🦆',
            isLeader: row['id'] == id || row['role'] == 'LIDER_VECINAL',
          );
        }
      } catch (_) {
        remoteListings = [];
        remoteResources = [];
      }
    }
    _prefs.setString(
      'profile_$id',
      jsonEncode({
        'id': remoteCommunity.id,
        'name': remoteCommunity.name,
        'area': remoteCommunity.area,
        'lat': remoteCommunity.lat,
        'lng': remoteCommunity.lng,
        'displayName': name,
        'boundary': [
          for (final p in boundary) [p.latitude, p.longitude],
        ],
      }),
    );
    notifyListeners();
  }

  Future<void> refreshRemote() async {
    if (authenticatedNeighbor == null) return;
    final client = Supabase.instance.client;
    final cid = community.id;
    try {
      final people = await client
          .from('profiles')
          .select('id,display_name,role')
          .eq('community_id', cid)
          .eq('status', 'ACTIVO');
      final raw = await client
          .from('listings')
          .select()
          .eq('community_id', cid)
          .eq('status', 'ACTIVO')
          .order('created_at', ascending: false);
      final resources = await client
          .from('emergency_resources')
          .select()
          .eq('community_id', cid);
      final votes = await client
          .from('recommendations')
          .select('listing_id,voter_id');
      final byListing = <String, Set<String>>{};
      for (final vote in votes) {
        (byListing[vote['listing_id'] as String] ??= <String>{}).add(
          vote['voter_id'] as String,
        );
      }
      final loaded = <Listing>[];
      for (final row in raw) {
        String? imageUrl;
        try {
          imageUrl = await client.storage
              .from('listing-photos')
              .createSignedUrl(row['photo_storage_path'] as String, 600);
        } catch (_) {}
        loaded.add(
          Listing(
            id: row['id'] as String,
            ownerId: row['seller_id'] as String,
            communityId: row['community_id'] as String,
            kind: row['kind'] == 'SERVICE' ? 'Servicio' : 'Producto',
            category: row['category'] as String,
            title: row['title'] as String,
            description: row['description'] as String,
            price: (row['price'] as num).toDouble(),
            zone: row['zone'] as String,
            lat: (row['lat'] as num?)?.toDouble() ?? community.lat,
            lng: (row['lng'] as num?)?.toDouble() ?? community.lng,
            createdAt: DateTime.parse(row['created_at'] as String),
            whatsapp: row['whatsapp_public'] as String?,
            photoUrl: imageUrl,
            isRemote: true,
            voters: byListing[row['id'] as String] ?? <String>{},
          ),
        );
      }
      if (authenticatedNeighbor == null || community.id != cid) return;
      remoteNeighbors = {
        for (final p in people)
          p['id'] as String: Neighbor(
            id: p['id'] as String,
            name: p['display_name'] as String,
            communityId: cid,
            avatar: '🦆',
            isLeader: p['id'] == currentUserId || p['role'] == 'LIDER_VECINAL',
          ),
      };
      remoteListings = loaded;
      remoteResources = List<Map<String, dynamic>>.from(resources);
      _prefs.setString(
        'community_data_$cid',
        jsonEncode({
          'people': people,
          'listings': loaded.map((l) => l.toJson()).toList(),
          'resources': resources,
        }),
      );
      remoteError = null;
      notifyListeners();
    } catch (_) {
      remoteError = 'Sin conexión: se muestran datos guardados y ejemplos.';
      notifyListeners();
    }
  }

  void clearProfile() {
    authenticatedNeighbor = null;
    activeCommunity = null;
    communityBoundary = [];
    remoteListings = [];
    remoteResources = [];
    remoteNeighbors = {};
    remoteError = null;
    currentUserId = 'ana';
    notifyListeners();
  }

  List<Neighbor> get demoNeighbors => authenticatedNeighbor == null
      ? []
      : [
          Neighbor(
            id: 'demo-leader',
            name: 'Coordinación de prueba',
            communityId: community.id,
            avatar: '🦆',
            isLeader: true,
          ),
          Neighbor(
            id: 'demo-rosa',
            name: 'Rosa (ejemplo)',
            communityId: community.id,
            avatar: '🦆',
          ),
          Neighbor(
            id: 'demo-carlos',
            name: 'Carlos (ejemplo)',
            communityId: community.id,
            avatar: '🦆',
          ),
        ];

  List<Listing> get demoListings => authenticatedNeighbor == null
      ? []
      : [
          Listing(
            id: 'demo-pan',
            ownerId: 'demo-rosa',
            communityId: community.id,
            kind: 'Producto',
            category: 'Alimentos',
            title: 'Pan casero (ejemplo)',
            description: 'Publicación ficticia para explorar el mercado.',
            price: 8,
            zone: 'Ubicación ficticia',
            lat: containsPoint(community.lat + 0.0012, community.lng + 0.0008)
                ? community.lat + 0.0012
                : community.lat,
            lng: containsPoint(community.lat + 0.0012, community.lng + 0.0008)
                ? community.lng + 0.0008
                : community.lng,
            createdAt: DateTime(2026, 11, 7),
            voters: _demoVoters('demo-pan'),
          ),
          Listing(
            id: 'demo-reparacion',
            ownerId: 'demo-carlos',
            communityId: community.id,
            kind: 'Servicio',
            category: 'Hogar',
            title: 'Reparaciones (ejemplo)',
            description: 'Servicio ficticio para explorar la interfaz.',
            price: 25,
            zone: 'Ubicación ficticia',
            lat: containsPoint(community.lat - 0.001, community.lng - 0.001)
                ? community.lat - 0.001
                : community.lat,
            lng: containsPoint(community.lat - 0.001, community.lng - 0.001)
                ? community.lng - 0.001
                : community.lng,
            createdAt: DateTime(2026, 11, 7),
            voters: _demoVoters('demo-reparacion'),
          ),
        ];

  void switchUser(String id) {
    if (authenticatedNeighbor != null) return;
    if (!neighbors.any((n) => n.id == id)) return;
    currentUserId = id;
    _prefs.setString('currentUserId', id);
    notifyListeners();
  }

  void finishIntro() {
    introSeen = true;
    _prefs.setBool('introSeen', true);
    notifyListeners();
  }

  void resetIntro() {
    introSeen = false;
    _prefs.setBool('introSeen', false);
    notifyListeners();
  }

  void addListing(Listing listing) {
    listings.add(listing);
    _save();
  }

  Set<String> _demoVoters(String listingId) =>
      _prefs.getStringList('demo_votes_${community.id}_$listingId')?.toSet() ??
      <String>{};

  bool toggleVote(Listing listing) {
    if (listing.kind != 'Servicio' ||
        listing.ownerId == currentUserId ||
        listing.communityId != currentUser.communityId) {
      return false;
    }
    if (!listing.voters.add(currentUserId)) {
      listing.voters.remove(currentUserId);
    }
    _save();
    return true;
  }

  Future<bool> toggleVoteFor(Listing listing) async {
    if (!listing.isRemote && listing.id.startsWith('demo-')) {
      if (listing.kind != 'Servicio' ||
          listing.ownerId == currentUserId ||
          listing.communityId != community.id) {
        return false;
      }
      final voters = _demoVoters(listing.id);
      if (!voters.add(currentUserId)) voters.remove(currentUserId);
      await _prefs.setStringList(
        'demo_votes_${community.id}_${listing.id}',
        voters.toList(),
      );
      listing.voters.clear();
      listing.voters.addAll(voters);
      notifyListeners();
      return true;
    }
    if (!listing.isRemote) return toggleVote(listing);
    if (listing.kind != 'Servicio' ||
        listing.ownerId == currentUserId ||
        listing.communityId != community.id) {
      return false;
    }
    final client = Supabase.instance.client;
    try {
      if (listing.voters.contains(currentUserId)) {
        await client
            .from('recommendations')
            .delete()
            .eq('listing_id', listing.id)
            .eq('voter_id', currentUserId);
        listing.voters.remove(currentUserId);
      } else {
        await client.from('recommendations').insert({
          'listing_id': listing.id,
          'voter_id': currentUserId,
        });
        listing.voters.add(currentUserId);
      }
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  void addHelp(HelpPost post) {
    helpPosts.add(post);
    _save();
  }

  bool respond(HelpPost post, String message) {
    if (post.communityId != currentUser.communityId ||
        post.authorId == currentUserId ||
        post.status != 'ABIERTA' ||
        message.trim().isEmpty) {
      return false;
    }
    post.responses.add(
      HelpResponse(
        id: newId(),
        authorId: currentUserId,
        message: message.trim(),
        createdAt: DateTime.now(),
      ),
    );
    _save();
    return true;
  }

  bool accept(HelpPost post, String responseId) {
    if (post.authorId != currentUserId ||
        post.status != 'ABIERTA' ||
        !post.responses.any((r) => r.id == responseId)) {
      return false;
    }
    post.acceptedResponseId = responseId;
    post.status = 'EN_COORDINACION';
    _save();
    return true;
  }

  bool closeHelp(HelpPost post, String status) {
    if (post.authorId != currentUserId ||
        !['RESUELTA', 'CANCELADA'].contains(status) ||
        ['RESUELTA', 'CANCELADA'].contains(post.status)) {
      return false;
    }
    post.status = status;
    _save();
    return true;
  }

  void _save() {
    _prefs.setString(
      'listings',
      jsonEncode(listings.map((e) => e.toJson()).toList()),
    );
    _prefs.setString(
      'helpPosts',
      jsonEncode(helpPosts.map((e) => e.toJson()).toList()),
    );
    notifyListeners();
  }

  static String newId() => DateTime.now().microsecondsSinceEpoch.toString();

  List<Listing> _seedListings() {
    final now = DateTime.now();
    return [
      Listing(
        id: 's1',
        ownerId: 'luis',
        communityId: 'palmeras',
        kind: 'Servicio',
        category: 'Gasfitería',
        title: 'Reparaciones de gasfitería',
        description: 'Atención para reparaciones domésticas. Ficha ficticia de demostración.',
        price: 35,
        zone: 'Sector central',
        lat: -11.9374,
        lng: -76.6955,
        createdAt: now.subtract(const Duration(days: 2)),
        voters: {'ana', 'maria'},
      ),
      Listing(
        id: 's2',
        ownerId: 'maria',
        communityId: 'palmeras',
        kind: 'Servicio',
        category: 'Clases',
        title: 'Clases de matemática',
        description:
            'Apoyo escolar en la zona. Ficha ficticia de demostración.',
        price: 25,
        zone: 'Sector norte',
        lat: -11.9366,
        lng: -76.6968,
        createdAt: now.subtract(const Duration(days: 1)),
        voters: {'ana'},
      ),
      Listing(
        id: 'p1',
        ownerId: 'pedro',
        communityId: 'palmeras',
        kind: 'Producto',
        category: 'Alimentos',
        title: 'Pan artesanal',
        description: 'Producto ficticio para probar el mercado.',
        price: 8,
        zone: 'Sector este',
        lat: -11.9385,
        lng: -76.6948,
        createdAt: now,
      ),
      Listing(
        id: 's3',
        ownerId: 'jose',
        communityId: 'olivos',
        kind: 'Servicio',
        category: 'Electricidad',
        title: 'Electricista del barrio',
        description: 'Ficha ficticia de demostración.',
        price: 40,
        zone: 'Sector sur',
        lat: -11.9425,
        lng: -76.7005,
        createdAt: now.subtract(const Duration(days: 1)),
        voters: {'carmen'},
      ),
    ];
  }

  List<HelpPost> _seedHelp() {
    final now = DateTime.now();
    return [
      HelpPost(
        id: 'h1',
        authorId: 'ana',
        communityId: 'palmeras',
        direction: 'Necesito',
        mode: 'Préstamo',
        title: 'Silla de ruedas por unos días',
        description: 'Ejemplo ficticio: necesito una silla de ruedas prestada.',
        createdAt: now.subtract(const Duration(hours: 3)),
      ),
      HelpPost(
        id: 'h2',
        authorId: 'maria',
        communityId: 'palmeras',
        direction: 'Ofrezco',
        mode: 'Donación',
        title: 'Frazadas para compartir',
        description: 'Ejemplo ficticio de ayuda solidaria sin dinero.',
        createdAt: now.subtract(const Duration(days: 1)),
      ),
      HelpPost(
        id: 'h3',
        authorId: 'carmen',
        communityId: 'olivos',
        direction: 'Ofrezco',
        mode: 'Voluntariado',
        title: 'Apoyo para cargar compras',
        description: 'Ejemplo ficticio de apoyo comunitario.',
        createdAt: now,
      ),
    ];
  }
}
