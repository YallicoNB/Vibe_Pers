const communityGroupLabels = <String, String>{
  'BRIGADA': 'Brigada vecinal',
  'EMPRENDEDORES': 'Pato Emprendedores',
  'DONADORES': 'Pato Donadores',
};

class CommunityAnnouncement {
  const CommunityAnnouncement({
    required this.id,
    required this.communityId,
    required this.authorId,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    this.meetingAt,
    this.meetingPlace,
    this.expiresAt,
  });

  final String id, communityId, authorId, kind, title, body;
  final DateTime createdAt;
  final DateTime? meetingAt, expiresAt;
  final String? meetingPlace;
  bool get isEmergency => kind == 'EMERGENCY';
  bool get isMeeting => kind == 'MEETING';

  factory CommunityAnnouncement.fromJson(Map<String, dynamic> data) =>
      CommunityAnnouncement(
        id: data['id'] as String,
        communityId: data['community_id'] as String,
        authorId: data['author_id'] as String,
        kind: data['kind'] as String,
        title: data['title'] as String,
        body: data['body'] as String,
        createdAt: DateTime.parse(data['created_at'] as String),
        meetingAt: data['meeting_at'] == null
            ? null
            : DateTime.parse(data['meeting_at'] as String),
        meetingPlace: data['meeting_place'] as String?,
        expiresAt: data['expires_at'] == null
            ? null
            : DateTime.parse(data['expires_at'] as String),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'community_id': communityId,
    'author_id': authorId,
    'kind': kind,
    'title': title,
    'body': body,
    'created_at': createdAt.toIso8601String(),
    'meeting_at': meetingAt?.toIso8601String(),
    'meeting_place': meetingPlace,
    'expires_at': expiresAt?.toIso8601String(),
  };
}
