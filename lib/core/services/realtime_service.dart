import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';

typedef ParticipantCallback = void Function(List<Participant> participants);
typedef SessionCallback = void Function(GameSession session);
typedef QuestionCallback = void Function(SessionQuestion question);
typedef CurseCallback = void Function(List<ActiveCurse> curses);
typedef CardCallback = void Function(List<HiderCard> cards);

class RealtimeService {
  final SupabaseClient _client;
  final Map<String, RealtimeChannel> _channels = {};
  final Map<String, StreamController> _controllers = {};

  RealtimeService(this._client);

  // ============ Session Realtime ============

  Stream<GameSession> subscribeToSession(String sessionId) {
    final key = 'session:$sessionId';
    if (_controllers.containsKey(key)) {
      return _controllers[key]!.stream as Stream<GameSession>;
    }

    final controller = StreamController<GameSession>.broadcast();
    _controllers[key] = controller;

    final channel = _client.channel('session:$sessionId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'sessions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: sessionId,
          ),
          callback: (payload) {
            final data = payload.newRecord;
            final session = GameSession.fromJson(_sessionFromDb(data));
            controller.add(session);
          },
        )
        .subscribe();

    _channels[key] = channel;
    return controller.stream;
  }

  // ============ Participants Realtime ============

  Stream<List<Participant>> subscribeToParticipants(String sessionId) {
    final key = 'participants:$sessionId';
    if (_controllers.containsKey(key)) {
      return _controllers[key]!.stream as Stream<List<Participant>>;
    }

    final controller = StreamController<List<Participant>>.broadcast();
    _controllers[key] = controller;

    final channel = _client.channel('participants:$sessionId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'participants',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'session_id',
            value: sessionId,
          ),
          callback: (payload) async {
            // Fetch fresh list on any change
            final response = await _client
                .from('participants')
                .select()
                .eq('session_id', sessionId)
                .order('joined_at');
            final participants = (response as List)
                .map((e) =>
                    Participant.fromJson(_participantFromDb(e)))
                .toList();
            controller.add(participants);
          },
        )
        .subscribe();

    _channels[key] = channel;
    return controller.stream;
  }

  // ============ Questions Realtime ============

  Stream<SessionQuestion> subscribeToNewQuestions(String sessionId) {
    final key = 'questions:$sessionId';
    if (_controllers.containsKey(key)) {
      return _controllers[key]!.stream as Stream<SessionQuestion>;
    }

    final controller = StreamController<SessionQuestion>.broadcast();
    _controllers[key] = controller;

    final channel = _client.channel('questions:$sessionId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'session_questions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'session_id',
            value: sessionId,
          ),
          callback: (payload) {
            final data = payload.newRecord;
            final question =
                SessionQuestion.fromJson(_sessionQuestionFromDb(data));
            controller.add(question);
          },
        )
        .subscribe();

    _channels[key] = channel;
    return controller.stream;
  }

  Stream<SessionQuestion> subscribeToQuestionUpdates(String sessionId) {
    final key = 'question_updates:$sessionId';
    if (_controllers.containsKey(key)) {
      return _controllers[key]!.stream as Stream<SessionQuestion>;
    }

    final controller = StreamController<SessionQuestion>.broadcast();
    _controllers[key] = controller;

    final channel = _client.channel('question_updates:$sessionId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'session_questions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'session_id',
            value: sessionId,
          ),
          callback: (payload) {
            final data = payload.newRecord;
            final question =
                SessionQuestion.fromJson(_sessionQuestionFromDb(data));
            controller.add(question);
          },
        )
        .subscribe();

    _channels[key] = channel;
    return controller.stream;
  }

  // ============ Cards Realtime ============

  Stream<List<HiderCard>> subscribeToCards(String sessionId) {
    final key = 'cards:$sessionId';
    if (_controllers.containsKey(key)) {
      return _controllers[key]!.stream as Stream<List<HiderCard>>;
    }

    final controller = StreamController<List<HiderCard>>.broadcast();
    _controllers[key] = controller;

    final channel = _client.channel('cards:$sessionId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'hider_cards',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'session_id',
            value: sessionId,
          ),
          callback: (payload) async {
            final response = await _client
                .from('hider_cards')
                .select()
                .eq('session_id', sessionId)
                .order('drawn_at');
            final cards = (response as List)
                .map((e) => HiderCard.fromJson(_hiderCardFromDb(e)))
                .toList();
            controller.add(cards);
          },
        )
        .subscribe();

    _channels[key] = channel;
    return controller.stream;
  }

  // ============ Curses Realtime ============

  Stream<List<ActiveCurse>> subscribeToCurses(String sessionId) {
    final key = 'curses:$sessionId';
    if (_controllers.containsKey(key)) {
      return _controllers[key]!.stream as Stream<List<ActiveCurse>>;
    }

    final controller = StreamController<List<ActiveCurse>>.broadcast();
    _controllers[key] = controller;

    final channel = _client.channel('curses:$sessionId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'active_curses',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'session_id',
            value: sessionId,
          ),
          callback: (payload) async {
            final response = await _client
                .from('active_curses')
                .select()
                .eq('session_id', sessionId)
                .order('started_at');
            final curses = (response as List)
                .map((e) => ActiveCurse.fromJson(_activeCurseFromDb(e)))
                .toList();
            controller.add(curses);
          },
        )
        .subscribe();

    _channels[key] = channel;
    return controller.stream;
  }

  // ============ Presence ============

  RealtimeChannel joinPresence(
    String sessionId,
    String participantId,
    Map<String, dynamic> userState,
  ) {
    final channel = _client.channel(
      'presence:$sessionId',
      opts: const RealtimeChannelConfig(self: true),
    );

    channel
        .onPresenceSync((payload) {
          // Handle presence sync
        })
        .onPresenceJoin((payload) {
          // Handle user joining
        })
        .onPresenceLeave((payload) {
          // Handle user leaving
        })
        .subscribe((status, [error]) async {
          if (status == RealtimeSubscribeStatus.subscribed) {
            await channel.track(userState);
          }
        });

    _channels['presence:$sessionId'] = channel;
    return channel;
  }

  // ============ Broadcast (Location Pings) ============

  RealtimeChannel setupLocationBroadcast(
    String sessionId,
    void Function(Map<String, dynamic> payload) onLocationUpdate,
  ) {
    final channel = _client.channel('location:$sessionId');

    channel
        .onBroadcast(
          event: 'location_update',
          callback: (payload) {
            onLocationUpdate(payload);
          },
        )
        .subscribe();

    _channels['location:$sessionId'] = channel;
    return channel;
  }

  Future<void> broadcastLocation(
    String sessionId, {
    required String participantId,
    required double lat,
    required double lng,
  }) async {
    final channel = _channels['location:$sessionId'];
    if (channel != null) {
      await channel.sendBroadcastMessage(
        event: 'location_update',
        payload: {
          'participant_id': participantId,
          'lat': lat,
          'lng': lng,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    }
  }

  // ============ Cleanup ============

  void unsubscribe(String key) {
    _channels[key]?.unsubscribe();
    _channels.remove(key);
    _controllers[key]?.close();
    _controllers.remove(key);
  }

  void unsubscribeAll() {
    for (final channel in _channels.values) {
      channel.unsubscribe();
    }
    for (final controller in _controllers.values) {
      controller.close();
    }
    _channels.clear();
    _controllers.clear();
  }

  // ============ Helpers ============

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
}
