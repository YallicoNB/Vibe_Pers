class Neighbor {
  const Neighbor({
    required this.id,
    required this.name,
    required this.communityId,
    required this.avatar,
    this.isLeader = false,
    this.supportRole,
  });
  final String id;
  final String name;
  final String communityId;
  final String avatar;
  final bool isLeader;
  final String? supportRole;
}

class Community {
  const Community({
    required this.id,
    required this.name,
    required this.area,
    required this.lat,
    required this.lng,
  });
  final String id;
  final String name;
  final String area;
  final double lat;
  final double lng;
}

class Listing {
  Listing({
    required this.id,
    required this.ownerId,
    required this.communityId,
    required this.kind,
    required this.category,
    required this.title,
    required this.description,
    required this.price,
    required this.zone,
    required this.lat,
    required this.lng,
    required this.createdAt,
    this.whatsapp,
    this.photoPath,
    this.photoUrl,
    this.isRemote = false,
    Set<String>? voters,
  }) : voters = voters ?? {};

  final String id,
      ownerId,
      communityId,
      kind,
      category,
      title,
      description,
      zone;
  final double price, lat, lng;
  final DateTime createdAt;
  final String? whatsapp, photoPath, photoUrl;
  final bool isRemote;
  final Set<String> voters;

  Map<String, dynamic> toJson() => {
    'id': id,
    'ownerId': ownerId,
    'communityId': communityId,
    'kind': kind,
    'category': category,
    'title': title,
    'description': description,
    'price': price,
    'zone': zone,
    'lat': lat,
    'lng': lng,
    'createdAt': createdAt.toIso8601String(),
    'whatsapp': whatsapp,
    'photoPath': photoPath,
    'photoUrl': photoUrl,
    'isRemote': isRemote,
    'voters': voters.toList(),
  };
  factory Listing.fromJson(Map<String, dynamic> j) => Listing(
    id: j['id'] as String,
    ownerId: j['ownerId'] as String,
    communityId: j['communityId'] as String,
    kind: j['kind'] as String,
    category: j['category'] as String,
    title: j['title'] as String,
    description: j['description'] as String,
    price: (j['price'] as num).toDouble(),
    zone: j['zone'] as String,
    lat: (j['lat'] as num).toDouble(),
    lng: (j['lng'] as num).toDouble(),
    createdAt: DateTime.parse(j['createdAt'] as String),
    whatsapp: j['whatsapp'] as String?,
    photoPath: j['photoPath'] as String?,
    photoUrl: j['photoUrl'] as String?,
    isRemote: j['isRemote'] as bool? ?? false,
    voters: Set<String>.from(j['voters'] as List? ?? []),
  );
}

class HelpResponse {
  HelpResponse({
    required this.id,
    required this.authorId,
    required this.message,
    required this.createdAt,
  });
  final String id, authorId, message;
  final DateTime createdAt;
  Map<String, dynamic> toJson() => {
    'id': id,
    'authorId': authorId,
    'message': message,
    'createdAt': createdAt.toIso8601String(),
  };
  factory HelpResponse.fromJson(Map<String, dynamic> j) => HelpResponse(
    id: j['id'] as String,
    authorId: j['authorId'] as String,
    message: j['message'] as String,
    createdAt: DateTime.parse(j['createdAt'] as String),
  );
}

class HelpPost {
  HelpPost({
    required this.id,
    required this.authorId,
    required this.communityId,
    required this.direction,
    required this.mode,
    required this.title,
    required this.description,
    required this.createdAt,
    this.status = 'ABIERTA',
    this.acceptedResponseId,
    List<HelpResponse>? responses,
  }) : responses = responses ?? [];
  final String id, authorId, communityId, direction, mode, title, description;
  final DateTime createdAt;
  String status;
  String? acceptedResponseId;
  final List<HelpResponse> responses;
  Map<String, dynamic> toJson() => {
    'id': id,
    'authorId': authorId,
    'communityId': communityId,
    'direction': direction,
    'mode': mode,
    'title': title,
    'description': description,
    'createdAt': createdAt.toIso8601String(),
    'status': status,
    'acceptedResponseId': acceptedResponseId,
    'responses': responses.map((e) => e.toJson()).toList(),
  };
  factory HelpPost.fromJson(Map<String, dynamic> j) => HelpPost(
    id: j['id'] as String,
    authorId: j['authorId'] as String,
    communityId: j['communityId'] as String,
    direction: j['direction'] as String,
    mode: j['mode'] as String,
    title: j['title'] as String,
    description: j['description'] as String,
    createdAt: DateTime.parse(j['createdAt'] as String),
    status: j['status'] as String? ?? 'ABIERTA',
    acceptedResponseId: j['acceptedResponseId'] as String?,
    responses: (j['responses'] as List? ?? [])
        .map((e) => HelpResponse.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
  );
}
