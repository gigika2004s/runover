class LatLngPoint {
  final double lat;
  final double lng;
  const LatLngPoint(this.lat, this.lng);

  factory LatLngPoint.fromJson(Map<String, dynamic> j) =>
      LatLngPoint((j['lat'] as num).toDouble(), (j['lng'] as num).toDouble());
}

class Territory {
  final String id;
  final String name;
  final List<LatLngPoint> coordinates;
  final LatLngPoint center;
  final double radiusM;
  final String status; // "disponivel" | "conquistado"
  final String? ownerType; // "user" | "team"
  final String? ownerDisplay;
  final int takeovers;

  const Territory({
    required this.id,
    required this.name,
    required this.coordinates,
    required this.center,
    required this.radiusM,
    required this.status,
    required this.ownerType,
    required this.ownerDisplay,
    this.takeovers = 0,
  });

  bool get isFree => status == 'disponivel';
  bool get isOwnedByTeam => ownerType == 'team';

  factory Territory.fromJson(Map<String, dynamic> j) => Territory(
    id: j['id'],
    name: j['name'],
    coordinates: (j['coordinates'] as List)
        .map((c) => LatLngPoint.fromJson(c))
        .toList(),
    center: LatLngPoint.fromJson(j['center']),
    radiusM: (j['radius_m'] as num).toDouble(),
    status: j['status'],
    ownerType: j['owner_type'],
    ownerDisplay: j['owner_display'],
    takeovers: (j['takeovers'] as num?)?.toInt() ?? 0,
  );
}

class OwnerHistoryEntry {
  final String ownerType;
  final String ownerDisplay;
  final DateTime conqueredAt;

  const OwnerHistoryEntry({
    required this.ownerType,
    required this.ownerDisplay,
    required this.conqueredAt,
  });

  factory OwnerHistoryEntry.fromJson(Map<String, dynamic> j) =>
      OwnerHistoryEntry(
        ownerType: j['owner_type'],
        ownerDisplay: j['owner_display'],
        conqueredAt: DateTime.parse(j['conquered_at']),
      );
}

class TerritoryDetail extends Territory {
  final DateTime? conquestAt;
  final int pointsValue;
  final List<OwnerHistoryEntry> history;
  final int? ownerPaceSecondsPerKm; // marca a bater — ritmo do dono
  final double? ownerDistanceM; // marca a bater — distância do dono
  final int? ownerDurationSeconds; // tempo máximo do desafio de distância

  const TerritoryDetail({
    required super.id,
    required super.name,
    required super.coordinates,
    required super.center,
    required super.radiusM,
    required super.status,
    required super.ownerType,
    required super.ownerDisplay,
    super.takeovers,
    required this.conquestAt,
    required this.pointsValue,
    this.history = const [],
    this.ownerPaceSecondsPerKm,
    this.ownerDistanceM,
    this.ownerDurationSeconds,
  });

  factory TerritoryDetail.fromJson(Map<String, dynamic> j) => TerritoryDetail(
    id: j['id'],
    name: j['name'],
    coordinates: (j['coordinates'] as List)
        .map((c) => LatLngPoint.fromJson(c))
        .toList(),
    center: LatLngPoint.fromJson(j['center']),
    radiusM: (j['radius_m'] as num).toDouble(),
    status: j['status'],
    ownerType: j['owner_type'],
    ownerDisplay: j['owner_display'],
    takeovers: (j['takeovers'] as num?)?.toInt() ?? 0,
    conquestAt: j['conquered_at'] != null
        ? DateTime.parse(j['conquered_at'])
        : null,
    pointsValue: j['points_value'],
    history: ((j['history'] as List?) ?? const [])
        .map((e) => OwnerHistoryEntry.fromJson(e))
        .toList(),
    ownerPaceSecondsPerKm: j['owner_pace_seconds_per_km'] as int?,
    ownerDistanceM: (j['owner_distance_m'] as num?)?.toDouble(),
    ownerDurationSeconds: j['owner_duration_seconds'] as int?,
  );
}

/// Território selvagem estilo Pokémon GO: aparece sozinho no mapa.
class WildSpawn {
  final String key;
  final LatLngPoint center;
  final double radiusM;
  final int relevance;
  final String rarity; // "comum" | "raro" | "épico"
  final DateTime spawnedAt;
  final DateTime expiresAt;

  const WildSpawn({
    required this.key,
    required this.center,
    required this.radiusM,
    required this.relevance,
    required this.rarity,
    required this.spawnedAt,
    required this.expiresAt,
  });

  factory WildSpawn.fromJson(Map<String, dynamic> j) => WildSpawn(
    key: j['key'],
    center: LatLngPoint.fromJson(j['center']),
    radiusM: (j['radius_m'] as num).toDouble(),
    relevance: j['relevance'] as int,
    rarity: j['rarity'],
    spawnedAt: DateTime.parse(j['spawned_at']),
    expiresAt: DateTime.parse(j['expires_at']),
  );
}

class UserProfile {
  final String id;
  final String fullName;
  final String username;
  final String email;
  final String? photoUrl;
  final int totalScore;
  final int territoriesCount;
  final int? rankPosition;
  final String? teamName;
  final int level; // RF11 / RN10
  final double levelProgress; // 0..1 até o próximo nível
  final int pointsToNextLevel;
  final bool isPublic; // RF05
  final int playSeconds; // RF19 — tempo de jogo

  const UserProfile({
    required this.id,
    required this.fullName,
    required this.username,
    required this.email,
    required this.photoUrl,
    required this.totalScore,
    required this.territoriesCount,
    required this.rankPosition,
    required this.teamName,
    required this.level,
    required this.levelProgress,
    required this.pointsToNextLevel,
    required this.isPublic,
    required this.playSeconds,
  });

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
    id: j['id'],
    fullName: j['full_name'],
    username: j['username'],
    email: j['email'],
    photoUrl: j['photo_url'],
    totalScore: j['total_score'],
    territoriesCount: j['territories_count'],
    rankPosition: j['rank_position'],
    teamName: j['team_name'],
    level: j['level'] ?? 1,
    levelProgress: (j['level_progress'] as num?)?.toDouble() ?? 0,
    pointsToNextLevel: j['points_to_next_level'] ?? 0,
    isPublic: j['is_public'] ?? true,
    playSeconds: j['play_seconds'] ?? 0,
  );
}

/// RF17 — perfil público de outro jogador (o back-end só devolve dados
/// públicos, e nega com 403 se o perfil estiver privado — RF05/RN13).
class PublicProfile {
  final String username;
  final String? photoUrl;
  final int totalScore;
  final int territoriesCount;
  final int? rankPosition;
  final String? teamName;
  final int level;
  final double levelProgress;
  final int pointsToNextLevel;

  const PublicProfile({
    required this.username,
    required this.photoUrl,
    required this.totalScore,
    required this.territoriesCount,
    required this.rankPosition,
    required this.teamName,
    required this.level,
    required this.levelProgress,
    required this.pointsToNextLevel,
  });

  factory PublicProfile.fromJson(Map<String, dynamic> j) => PublicProfile(
    username: j['username'],
    photoUrl: j['photo_url'],
    totalScore: j['total_score'],
    territoriesCount: j['territories_count'],
    rankPosition: j['rank_position'],
    teamName: j['team_name'],
    level: j['level'] ?? 1,
    levelProgress: (j['level_progress'] as num?)?.toDouble() ?? 0,
    pointsToNextLevel: j['points_to_next_level'] ?? 0,
  );
}

class TeamMemberInfo {
  final String username;
  final String? photoUrl;
  const TeamMemberInfo({required this.username, required this.photoUrl});

  factory TeamMemberInfo.fromJson(Map<String, dynamic> j) =>
      TeamMemberInfo(username: j['username'], photoUrl: j['photo_url']);
}

class TeamSummary {
  final String id;
  final String name;
  final String creatorUsername;
  final int memberCount;

  const TeamSummary({
    required this.id,
    required this.name,
    required this.creatorUsername,
    required this.memberCount,
  });

  factory TeamSummary.fromJson(Map<String, dynamic> j) => TeamSummary(
    id: j['id'],
    name: j['name'],
    creatorUsername: j['creator_username'],
    memberCount: j['member_count'],
  );
}

class TeamDetail extends TeamSummary {
  final List<TeamMemberInfo> members;
  final int totalScore;
  final int territoriesCount;
  final int level; // RF11 / RN10
  final double levelProgress;
  final int pointsToNextLevel;

  const TeamDetail({
    required super.id,
    required super.name,
    required super.creatorUsername,
    required super.memberCount,
    required this.members,
    required this.totalScore,
    required this.territoriesCount,
    required this.level,
    required this.levelProgress,
    required this.pointsToNextLevel,
  });

  factory TeamDetail.fromJson(Map<String, dynamic> j) => TeamDetail(
    id: j['id'],
    name: j['name'],
    creatorUsername: j['creator_username'],
    memberCount: j['member_count'],
    members: (j['members'] as List)
        .map((m) => TeamMemberInfo.fromJson(m))
        .toList(),
    totalScore: j['total_score'],
    territoriesCount: j['territories_count'],
    level: j['level'] ?? 1,
    levelProgress: (j['level_progress'] as num?)?.toDouble() ?? 0,
    pointsToNextLevel: j['points_to_next_level'] ?? 0,
  );
}

class RankingEntry {
  final int position;
  final String ownerType; // "user" | "team"
  final String name;
  final String? photoUrl;
  final int totalScore;
  final int territoriesCount;
  final int level; // RF11 / RN10

  const RankingEntry({
    required this.position,
    required this.ownerType,
    required this.name,
    this.photoUrl,
    required this.totalScore,
    required this.territoriesCount,
    required this.level,
  });

  factory RankingEntry.fromJson(Map<String, dynamic> j) => RankingEntry(
    position: j['position'],
    ownerType: j['owner_type'],
    name: j['name'],
    photoUrl: j['photo_url'],
    totalScore: j['total_score'],
    territoriesCount: j['territories_count'],
    level: j['level'] ?? 1,
  );
}

class HistoryEntry {
  final String? territoryName;
  final int delta;
  final String reason;
  final DateTime createdAt;

  const HistoryEntry({
    required this.territoryName,
    required this.delta,
    required this.reason,
    required this.createdAt,
  });

  factory HistoryEntry.fromJson(Map<String, dynamic> j) => HistoryEntry(
    territoryName: j['territory_name'],
    delta: j['delta'],
    reason: j['reason'],
    createdAt: DateTime.parse(j['created_at']),
  );
}

class NotificationEntry {
  final String id;
  final String message;
  final String type;
  final bool isRead;
  final DateTime createdAt;

  const NotificationEntry({
    required this.id,
    required this.message,
    required this.type,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationEntry.fromJson(Map<String, dynamic> j) =>
      NotificationEntry(
        id: j['id'],
        message: j['message'],
        type: j['type'],
        isRead: j['is_read'],
        createdAt: DateTime.parse(j['created_at']),
      );
}
