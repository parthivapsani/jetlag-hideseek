CREATE TABLE game_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    round_id UUID REFERENCES rounds(id),
    event_type VARCHAR(50) NOT NULL,
    payload JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    CONSTRAINT valid_event_type CHECK (event_type IN (
        'phase_change', 'question_asked', 'question_answered',
        'card_drawn', 'card_played', 'curse_activated',
        'location_update', 'timer_pause', 'timer_resume',
        'player_joined', 'player_left', 'round_started', 'round_ended',
        'game_started', 'game_ended'
    ))
);

CREATE INDEX idx_game_events_session ON game_events(session_id, created_at);
CREATE INDEX idx_game_events_round ON game_events(round_id, created_at);
CREATE INDEX idx_game_events_type ON game_events(event_type);

ALTER TABLE game_events ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can view game events" ON game_events FOR SELECT USING (true);
CREATE POLICY "Anyone can create game events" ON game_events FOR INSERT WITH CHECK (true);

ALTER PUBLICATION supabase_realtime ADD TABLE game_events;
