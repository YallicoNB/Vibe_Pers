import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'community_geometry.dart';
import 'demo_emergency.dart';
import 'community_updates.dart';

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
    final savedGroups = prefs.getString('local_community_groups');
    if (savedGroups != null) {
      try {
        store.localGroups = Map<String, String>.from(
          jsonDecode(savedGroups) as Map,
        );
      } catch (_) {}
    }
    final savedAnnouncements = prefs.getString('local_community_announcements');
    if (savedAnnouncements != null) {
      try {
        store.localAnnouncements = (jsonDecode(savedAnnouncements) as List)
            .map(
              (row) => CommunityAnnouncement.fromJson(
                Map<String, dynamic>.from(row as Map),
              ),
            )
            .toList();
      } catch (_) {}
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
  Map<String, String> remoteGroups = {};
  Map<String, String> localGroups = {};
  List<CommunityAnnouncement> remoteAnnouncements = [];
  List<CommunityAnnouncement> localAnnouncements = [];
  Set<String> readAnnouncementIds = {};
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
    List<LatLng> boundary, {
    bool isLeader = false,
  }) {
    activeCommunity = remoteCommunity;
    communityBoundary = boundary;
    authenticatedNeighbor = Neighbor(
      id: id,
      name: name,
      communityId: remoteCommunity.id,
      avatar: '🦆',
      isLeader: isLeader,
    );
    currentUserId = id;
    remoteNeighbors = {id: authenticatedNeighbor!};
    remoteGroups = {};
    remoteAnnouncements = [];
    readAnnouncementIds = {};
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
        remoteGroups = Map<String, String>.from(data['groups'] as Map? ?? {});
        remoteAnnouncements = (data['announcements'] as List? ?? [])
            .map(
              (e) => CommunityAnnouncement.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList();
        readAnnouncementIds = (data['readIds'] as List? ?? [])
            .cast<String>()
            .toSet();
        for (final p in data['people'] as List) {
          final row = Map<String, dynamic>.from(p as Map);
          remoteNeighbors[row['id'] as String] = Neighbor(
            id: row['id'] as String,
            name: row['display_name'] as String,
            communityId: remoteCommunity.id,
            avatar: '🦆',
            isLeader:
                row['role'] == 'LIDER_VECINAL' &&
                row['leader_community_id'] == remoteCommunity.id,
          );
        }
      } catch (_) {
        remoteListings = [];
        remoteResources = [];
      }
    }
    remoteNeighbors[id] = authenticatedNeighbor!;
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
          .select('id,display_name,role,leader_community_id')
          .eq('community_id', cid)
          .eq('status', 'ACTIVO');
      final groups = await client
          .from('community_groups')
          .select('member_id,demo_key,group_code')
          .eq('community_id', cid);
      final announcements = await client
          .from('community_announcements')
          .select()
          .eq('community_id', cid)
          .eq('status', 'ACTIVE')
          .order('created_at', ascending: false);
      final reads = await client
          .from('community_announcement_reads')
          .select('announcement_id')
          .eq('user_id', currentUserId);
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
            isLeader:
                p['role'] == 'LIDER_VECINAL' && p['leader_community_id'] == cid,
          ),
      };
      authenticatedNeighbor =
          remoteNeighbors[currentUserId] ?? authenticatedNeighbor;
      remoteGroups = {
        for (final group in groups)
          (group['member_id'] ?? group['demo_key']) as String:
              group['group_code'] as String,
      };
      remoteAnnouncements = announcements
          .map(
            (row) =>
                CommunityAnnouncement.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList();
      readAnnouncementIds = reads
          .map((row) => row['announcement_id'] as String)
          .toSet();
      remoteListings = loaded;
      remoteResources = List<Map<String, dynamic>>.from(resources);
      _prefs.setString(
        'community_data_$cid',
        jsonEncode({
          'people': people,
          'groups': remoteGroups,
          'announcements': remoteAnnouncements.map((a) => a.toJson()).toList(),
          'readIds': readAnnouncementIds.toList(),
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

  String? groupOf(Neighbor neighbor) => authenticatedNeighbor == null
      ? localGroups['${community.id}:${neighbor.id}']
      : remoteGroups[neighbor.id];

  List<CommunityAnnouncement> get communityAnnouncements {
    final now = DateTime.now();
    final source = authenticatedNeighbor == null
        ? localAnnouncements
        : remoteAnnouncements;
    return source
        .where(
          (announcement) =>
              announcement.communityId == community.id &&
              (announcement.expiresAt == null ||
                  announcement.expiresAt!.isAfter(now)),
        )
        .toList()
      ..sort((a, b) {
        if (a.isEmergency != b.isEmergency) return a.isEmergency ? -1 : 1;
        return b.createdAt.compareTo(a.createdAt);
      });
  }

  bool isAnnouncementRead(CommunityAnnouncement announcement) {
    if (announcement.authorId == currentUserId) return true;
    if (authenticatedNeighbor == null) {
      return (_prefs.getStringList('local_announcement_reads_$currentUserId') ??
              [])
          .contains(announcement.id);
    }
    return readAnnouncementIds.contains(announcement.id);
  }

  int get unreadAnnouncementCount {
    final reads = authenticatedNeighbor == null
        ? (_prefs.getStringList('local_announcement_reads_$currentUserId') ??
                  [])
              .toSet()
        : readAnnouncementIds;
    return communityAnnouncements
        .where(
          (announcement) =>
              announcement.authorId != currentUserId &&
              !reads.contains(announcement.id),
        )
        .length;
  }

  Future<void> assignGroup(Neighbor neighbor, String? code) async {
    if (!currentUser.isLeader ||
        neighbor.isLeader ||
        neighbor.id == currentUserId ||
        neighbor.communityId != community.id ||
        (code != null && !communityGroupLabels.containsKey(code))) {
      throw StateError('Solo el líder puede asignar vecinos de su junta.');
    }
    if (authenticatedNeighbor == null) {
      final key = '${community.id}:${neighbor.id}';
      if (code == null) {
        localGroups.remove(key);
      } else {
        localGroups[key] = code;
      }
      await _prefs.setString('local_community_groups', jsonEncode(localGroups));
      notifyListeners();
      return;
    }
    final isDemo = neighbor.id.startsWith('demo-');
    await Supabase.instance.client.rpc(
      'assign_community_group',
      params: {
        'p_member_id': isDemo ? null : neighbor.id,
        'p_demo_key': isDemo ? neighbor.id : null,
        'p_group_code': code,
      },
    );
    if (code == null) {
      remoteGroups.remove(neighbor.id);
    } else {
      remoteGroups[neighbor.id] = code;
    }
    notifyListeners();
    await refreshRemote();
  }

  Future<void> publishAnnouncement({
    required String kind,
    required String title,
    required String body,
    DateTime? meetingAt,
    String? meetingPlace,
  }) async {
    if (!currentUser.isLeader) {
      throw StateError('Solo el líder puede publicar avisos.');
    }
    if (authenticatedNeighbor == null) {
      localAnnouncements.add(
        CommunityAnnouncement(
          id: newId(),
          communityId: community.id,
          authorId: currentUserId,
          kind: kind,
          title: title.trim(),
          body: body.trim(),
          createdAt: DateTime.now(),
          meetingAt: meetingAt,
          meetingPlace: meetingPlace,
          expiresAt: kind == 'EMERGENCY'
              ? DateTime.now().add(const Duration(hours: 24))
              : null,
        ),
      );
      await _prefs.setString(
        'local_community_announcements',
        jsonEncode(
          localAnnouncements
              .map((announcement) => announcement.toJson())
              .toList(),
        ),
      );
      notifyListeners();
      return;
    }
    final createdId = await Supabase.instance.client.rpc(
      'create_community_announcement',
      params: {
        'p_kind': kind,
        'p_title': title.trim(),
        'p_body': body.trim(),
        'p_meeting_at': meetingAt?.toUtc().toIso8601String(),
        'p_meeting_place': meetingPlace?.trim(),
      },
    );
    remoteAnnouncements.insert(
      0,
      CommunityAnnouncement(
        id: createdId as String,
        communityId: community.id,
        authorId: currentUserId,
        kind: kind,
        title: title.trim(),
        body: body.trim(),
        createdAt: DateTime.now(),
        meetingAt: meetingAt,
        meetingPlace: meetingPlace,
        expiresAt: kind == 'EMERGENCY'
            ? DateTime.now().add(const Duration(hours: 24))
            : null,
      ),
    );
    notifyListeners();
    await refreshRemote();
  }

  Future<void> closeAnnouncement(CommunityAnnouncement announcement) async {
    if (!currentUser.isLeader || announcement.communityId != community.id) {
      throw StateError('Solo el líder puede cerrar avisos de su junta.');
    }
    if (authenticatedNeighbor == null) {
      localAnnouncements.removeWhere((a) => a.id == announcement.id);
      await _prefs.setString(
        'local_community_announcements',
        jsonEncode(localAnnouncements.map((a) => a.toJson()).toList()),
      );
      notifyListeners();
      return;
    }
    await Supabase.instance.client.rpc(
      'close_community_announcement',
      params: {'p_id': announcement.id},
    );
    remoteAnnouncements.removeWhere((a) => a.id == announcement.id);
    notifyListeners();
    await refreshRemote();
  }

  Future<void> markAnnouncementRead(CommunityAnnouncement announcement) async {
    if (authenticatedNeighbor == null) {
      final key = 'local_announcement_reads_$currentUserId';
      final reads = (_prefs.getStringList(key) ?? []).toSet()
        ..add(announcement.id);
      await _prefs.setStringList(key, reads.toList());
    } else {
      await Supabase.instance.client.rpc(
        'mark_community_announcement_read',
        params: {'p_id': announcement.id},
      );
      readAnnouncementIds.add(announcement.id);
      final cacheKey = 'community_data_${community.id}';
      final cached = _prefs.getString(cacheKey);
      if (cached != null) {
        try {
          final data = Map<String, dynamic>.from(jsonDecode(cached) as Map);
          data['readIds'] = readAnnouncementIds.toList();
          await _prefs.setString(cacheKey, jsonEncode(data));
        } catch (_) {}
      }
    }
    notifyListeners();
  }

  void clearProfile() {
    authenticatedNeighbor = null;
    activeCommunity = null;
    communityBoundary = [];
    remoteListings = [];
    remoteResources = [];
    remoteNeighbors = {};
    remoteGroups = {};
    remoteAnnouncements = [];
    readAnnouncementIds = {};
    remoteError = null;
    currentUserId = 'ana';
    notifyListeners();
  }

  List<Neighbor> get demoNeighbors => authenticatedNeighbor == null
      ? []
      : [
          Neighbor(
            id: 'demo-rosa',
            name: 'Rosa',
            communityId: community.id,
            avatar: '🦆',
          ),
          Neighbor(
            id: 'demo-carlos',
            name: 'Carlos',
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
