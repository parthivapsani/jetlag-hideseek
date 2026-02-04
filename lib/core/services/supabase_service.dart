import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';

class SupabaseService {
  final SupabaseClient _client;

  SupabaseService(this._client);

  SupabaseClient get client => _client;

  // ============ Game Areas ============

  Future<List<GameArea>> getGameAreas({String? createdBy}) async {
    var query = _client.from('game_areas').select();
    if (createdBy != null) {
      query = query.eq('created_by', createdBy);
    }
    final response = await query.order('created_at', ascending: false);
    return (response as List).map((e) => _gameAreaFromDb(e)).toList();
  }

  Future<GameArea?> getGameArea(String id) async {
    final response =
        await _client.from('game_areas').select().eq('id', id).maybeSingle();
    if (response == null) return null;
    return _gameAreaFromDb(response);
  }

  Future<GameArea> createGameArea(GameArea area) async {
    final data = _gameAreaToDb(area);
    final response =
        await _client.from('game_areas').insert(data).select().single();
    return _gameAreaFromDb(response);
  }

  Future<void> updateGameArea(GameArea area) async {
    await _client
        .from('game_areas')
        .update(_gameAreaToDb(area))
        .eq('id', area.id);
  }

  Future<void> deleteGameArea(String id) async {
    await _client.from('game_areas').delete().eq('id', id);
  }

  // ============ Sessions ============

  Future<GameSession?> getSession(String id) async {
    final response =
        await _client.from('sessions').select().eq('id', id).maybeSingle();
    if (response == null) return null;
    return GameSession.fromJson(_sessionFromDb(response));
  }

  Future<GameSession?> getSessionByRoomCode(String roomCode) async {
    final response = await _client
        .from('sessions')
        .select()
        .eq('room_code', roomCode.toUpperCase())
        .maybeSingle();
    if (response == null) return null;
    return GameSession.fromJson(_sessionFromDb(response));
  }

  Future<GameSession> createSession({
    required String gameAreaId,
    required int hidingPeriodSeconds,
    required double zoneRadiusMeters,
    required String createdBy,
  }) async {
    final roomCode = _generateRoomCode();
    final data = {
      'room_code': roomCode,
      'status': 'waiting',
      'game_area_id': gameAreaId,
      'hiding_period_seconds': hidingPeriodSeconds,
      'zone_radius_meters': zoneRadiusMeters,
      'created_by': createdBy,
    };
    final response =
        await _client.from('sessions').insert(data).select().single();
    return GameSession.fromJson(_sessionFromDb(response));
  }

  Future<void> updateSessionStatus(
    String sessionId,
    SessionStatus status, {
    DateTime? hidingStartedAt,
    DateTime? seekingStartedAt,
    DateTime? timerPausedAt,
    int? pausedTimeRemainingSeconds,
  }) async {
    final data = <String, dynamic>{
      'status': status.name,
    };
    if (hidingStartedAt != null) {
      data['hiding_started_at'] = hidingStartedAt.toIso8601String();
    }
    if (seekingStartedAt != null) {
      data['seeking_started_at'] = seekingStartedAt.toIso8601String();
    }
    if (timerPausedAt != null) {
      data['timer_paused_at'] = timerPausedAt.toIso8601String();
    }
    if (pausedTimeRemainingSeconds != null) {
      data['paused_time_remaining_seconds'] = pausedTimeRemainingSeconds;
    }
    await _client.from('sessions').update(data).eq('id', sessionId);
  }

  Future<void> endSession(String sessionId, {String? winnerId}) async {
    await _client.from('sessions').update({
      'status': 'ended',
      'ended_at': DateTime.now().toIso8601String(),
      'winner_id': winnerId,
    }).eq('id', sessionId);
  }

  // ============ Participants ============

  Future<List<Participant>> getParticipants(String sessionId) async {
    final response = await _client
        .from('participants')
        .select()
        .eq('session_id', sessionId)
        .order('joined_at');
    return (response as List)
        .map((e) => Participant.fromJson(_participantFromDb(e)))
        .toList();
  }

  Future<Participant> joinSession({
    required String sessionId,
    String? userId,
    required String displayName,
    required ParticipantRole role,
    required String deviceToken,
    bool isHost = false,
  }) async {
    final data = {
      'session_id': sessionId,
      'user_id': userId,
      'display_name': displayName,
      'role': role.name,
      'device_token': deviceToken,
      'is_host': isHost,
      'is_connected': true,
    };
    final response =
        await _client.from('participants').insert(data).select().single();
    return Participant.fromJson(_participantFromDb(response));
  }

  Future<void> updateParticipantRole(
      String participantId, ParticipantRole role) async {
    await _client
        .from('participants')
        .update({'role': role.name}).eq('id', participantId);
  }

  Future<void> updateParticipantLocation(
    String participantId, {
    required double lat,
    required double lng,
  }) async {
    await _client.from('participants').update({
      'last_location_lat': lat,
      'last_location_lng': lng,
      'last_location_at': DateTime.now().toIso8601String(),
    }).eq('id', participantId);
  }

  Future<void> setParticipantConnected(
      String participantId, bool isConnected) async {
    await _client
        .from('participants')
        .update({'is_connected': isConnected}).eq('id', participantId);
  }

  Future<void> leaveSession(String participantId) async {
    await _client.from('participants').delete().eq('id', participantId);
  }

  // ============ Questions ============

  Future<List<SessionQuestion>> getSessionQuestions(String sessionId) async {
    final response = await _client
        .from('session_questions')
        .select()
        .eq('session_id', sessionId)
        .order('asked_at', ascending: false);
    return (response as List)
        .map((e) => SessionQuestion.fromJson(_sessionQuestionFromDb(e)))
        .toList();
  }

  Future<SessionQuestion> askQuestion({
    required String sessionId,
    required String questionId,
    required QuestionCategory category,
    required String askedByParticipantId,
    required int responseTimeMinutes,
    bool testMode = false,
  }) async {
    final now = DateTime.now();
    final data = {
      'session_id': sessionId,
      'question_id': questionId,
      'category': category.name,
      'status': 'asked',
      'asked_by_participant_id': askedByParticipantId,
      'asked_at': now.toIso8601String(),
      'response_deadline':
          now.add(Duration(minutes: responseTimeMinutes)).toIso8601String(),
      'was_test_mode': testMode,
    };
    final response =
        await _client.from('session_questions').insert(data).select().single();
    return SessionQuestion.fromJson(_sessionQuestionFromDb(response));
  }

  Future<void> answerQuestion(
    String sessionQuestionId, {
    String? answerText,
    String? answerPhotoUrl,
    String? answerAudioUrl,
  }) async {
    await _client.from('session_questions').update({
      'status': 'answered',
      'answered_at': DateTime.now().toIso8601String(),
      'answer_text': answerText,
      'answer_photo_url': answerPhotoUrl,
      'answer_audio_url': answerAudioUrl,
    }).eq('id', sessionQuestionId);
  }

  Future<void> vetoQuestion(String sessionQuestionId) async {
    await _client.from('session_questions').update({
      'status': 'vetoed',
      'answered_at': DateTime.now().toIso8601String(),
    }).eq('id', sessionQuestionId);
  }

  // ============ Cards ============

  Future<List<HiderCard>> getHiderCards(String sessionId) async {
    final response = await _client
        .from('hider_cards')
        .select()
        .eq('session_id', sessionId)
        .order('drawn_at');
    return (response as List)
        .map((e) => HiderCard.fromJson(_hiderCardFromDb(e)))
        .toList();
  }

  Future<HiderCard> drawCard({
    required String sessionId,
    required String cardId,
  }) async {
    final data = {
      'session_id': sessionId,
      'card_id': cardId,
      'status': 'in_hand',
      'drawn_at': DateTime.now().toIso8601String(),
    };
    final response =
        await _client.from('hider_cards').insert(data).select().single();
    return HiderCard.fromJson(_hiderCardFromDb(response));
  }

  Future<void> playCard(String hiderCardId) async {
    await _client.from('hider_cards').update({
      'status': 'played',
      'played_at': DateTime.now().toIso8601String(),
    }).eq('id', hiderCardId);
  }

  Future<void> discardCard(String hiderCardId) async {
    await _client.from('hider_cards').update({
      'status': 'discarded',
      'discarded_at': DateTime.now().toIso8601String(),
    }).eq('id', hiderCardId);
  }

  // ============ Curses ============

  Future<List<ActiveCurse>> getActiveCurses(String sessionId) async {
    final response = await _client
        .from('active_curses')
        .select()
        .eq('session_id', sessionId)
        .order('started_at');
    return (response as List)
        .map((e) => ActiveCurse.fromJson(_activeCurseFromDb(e)))
        .toList();
  }

  Future<ActiveCurse> activateCurse({
    required String sessionId,
    required String cardId,
    required CurseType curseType,
    int? durationMinutes,
    String? condition,
    bool isBlocking = false,
  }) async {
    final now = DateTime.now();
    final data = {
      'session_id': sessionId,
      'card_id': cardId,
      'curse_type': curseType.name,
      'started_at': now.toIso8601String(),
      'expires_at': durationMinutes != null
          ? now.add(Duration(minutes: durationMinutes)).toIso8601String()
          : null,
      'is_blocking': isBlocking,
      'condition': condition,
    };
    final response =
        await _client.from('active_curses').insert(data).select().single();
    return ActiveCurse.fromJson(_activeCurseFromDb(response));
  }

  Future<void> deactivateCurse(String curseId) async {
    await _client.from('active_curses').delete().eq('id', curseId);
  }

  // ============ Time Traps ============

  Future<List<PlacedTimeTrap>> getTimeTraps(String sessionId) async {
    final response = await _client
        .from('placed_time_traps')
        .select()
        .eq('session_id', sessionId)
        .order('placed_at');
    return (response as List)
        .map((e) => PlacedTimeTrap.fromJson(_timeTrapFromDb(e)))
        .toList();
  }

  Future<PlacedTimeTrap> placeTimeTrap({
    required String sessionId,
    required String cardId,
    required String stationId,
    required String stationName,
    required double latitude,
    required double longitude,
  }) async {
    final data = {
      'session_id': sessionId,
      'card_id': cardId,
      'station_id': stationId,
      'station_name': stationName,
      'latitude': latitude,
      'longitude': longitude,
      'placed_at': DateTime.now().toIso8601String(),
    };
    final response =
        await _client.from('placed_time_traps').insert(data).select().single();
    return PlacedTimeTrap.fromJson(_timeTrapFromDb(response));
  }

  Future<void> triggerTimeTrap(
      String trapId, String triggeredByParticipantId) async {
    await _client.from('placed_time_traps').update({
      'triggered_at': DateTime.now().toIso8601String(),
      'triggered_by_participant_id': triggeredByParticipantId,
    }).eq('id', trapId);
  }

  // ============ Storage ============

  Future<String> uploadPhoto(String sessionId, String filePath) async {
    final fileName =
        '${sessionId}/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _client.storage.from('question_photos').upload(
          fileName,
          filePath as dynamic,
        );
    return _client.storage.from('question_photos').getPublicUrl(fileName);
  }

  Future<String> uploadAudio(String sessionId, String filePath) async {
    final fileName =
        '${sessionId}/${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _client.storage.from('question_audio').upload(
          fileName,
          filePath as dynamic,
        );
    return _client.storage.from('question_audio').getPublicUrl(fileName);
  }

  // ============ Helpers ============

  String _generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }

  // DB field mapping helpers
  GameArea _gameAreaFromDb(Map<String, dynamic> data) {
    return GameArea(
      id: data['id'],
      name: data['name'],
      inclusionPolygons: _parsePolygons(data['inclusion_polygons']),
      exclusionPolygons: _parsePolygons(data['exclusion_polygons']),
      centerLat: (data['center_lat'] as num).toDouble(),
      centerLng: (data['center_lng'] as num).toDouble(),
      defaultZoom: (data['default_zoom'] as num?)?.toDouble() ?? 12.0,
      createdBy: data['created_by'],
      createdAt: data['created_at'] != null
          ? DateTime.parse(data['created_at'])
          : null,
    );
  }

  Map<String, dynamic> _gameAreaToDb(GameArea area) {
    return {
      'id': area.id,
      'name': area.name,
      'inclusion_polygons': area.inclusionPolygons.map((p) => p.toJson()).toList(),
      'exclusion_polygons': area.exclusionPolygons.map((p) => p.toJson()).toList(),
      'center_lat': area.centerLat,
      'center_lng': area.centerLng,
      'default_zoom': area.defaultZoom,
      'created_by': area.createdBy,
    };
  }

  List<PolygonData> _parsePolygons(dynamic data) {
    if (data == null) return [];
    if (data is List) {
      return data.map((p) => PolygonData.fromJson(p as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Map<String, dynamic> _sessionFromDb(Map<String, dynamic> data) {
    return {
      'id': data['id'],
      'roomCode': data['room_code'],
      'status': data['status'],
      'gameAreaId': data['game_area_id'],
      'hidingPeriodSeconds': data['hiding_period_seconds'],
      'zoneRadiusMeters': data['zone_radius_meters'],
      'hidingStartedAt': data['hiding_started_at'],
      'seekingStartedAt': data['seeking_started_at'],
      'timerPausedAt': data['timer_paused_at'],
      'pausedTimeRemainingSeconds': data['paused_time_remaining_seconds'],
      'endedAt': data['ended_at'],
      'winnerId': data['winner_id'],
      'createdBy': data['created_by'],
      'createdAt': data['created_at'],
    };
  }

  Map<String, dynamic> _participantFromDb(Map<String, dynamic> data) {
    return {
      'id': data['id'],
      'sessionId': data['session_id'],
      'userId': data['user_id'],
      'displayName': data['display_name'],
      'role': data['role'],
      'deviceToken': data['device_token'],
      'isConnected': data['is_connected'],
      'isHost': data['is_host'],
      'lastLocationLat': data['last_location_lat'],
      'lastLocationLng': data['last_location_lng'],
      'lastLocationAt': data['last_location_at'],
      'joinedAt': data['joined_at'],
    };
  }

  Map<String, dynamic> _sessionQuestionFromDb(Map<String, dynamic> data) {
    return {
      'id': data['id'],
      'sessionId': data['session_id'],
      'questionId': data['question_id'],
      'category': data['category'],
      'status': data['status'],
      'askedByParticipantId': data['asked_by_participant_id'],
      'askedAt': data['asked_at'],
      'answeredAt': data['answered_at'],
      'responseDeadline': data['response_deadline'],
      'answerText': data['answer_text'],
      'answerPhotoUrl': data['answer_photo_url'],
      'answerAudioUrl': data['answer_audio_url'],
      'wasTestMode': data['was_test_mode'],
    };
  }

  Map<String, dynamic> _hiderCardFromDb(Map<String, dynamic> data) {
    return {
      'id': data['id'],
      'sessionId': data['session_id'],
      'cardId': data['card_id'],
      'status': data['status'],
      'drawnAt': data['drawn_at'],
      'playedAt': data['played_at'],
      'discardedAt': data['discarded_at'],
    };
  }

  Map<String, dynamic> _activeCurseFromDb(Map<String, dynamic> data) {
    return {
      'id': data['id'],
      'sessionId': data['session_id'],
      'cardId': data['card_id'],
      'curseType': data['curse_type'],
      'startedAt': data['started_at'],
      'expiresAt': data['expires_at'],
      'isBlocking': data['is_blocking'],
      'condition': data['condition'],
    };
  }

  Map<String, dynamic> _timeTrapFromDb(Map<String, dynamic> data) {
    return {
      'id': data['id'],
      'sessionId': data['session_id'],
      'cardId': data['card_id'],
      'stationId': data['station_id'],
      'stationName': data['station_name'],
      'latitude': data['latitude'],
      'longitude': data['longitude'],
      'placedAt': data['placed_at'],
      'triggeredAt': data['triggered_at'],
      'triggeredByParticipantId': data['triggered_by_participant_id'],
    };
  }
}
