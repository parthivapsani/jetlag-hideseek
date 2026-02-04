-- Jet Lag: Hide & Seek - Initial Database Schema
-- Run this migration to set up the database tables

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Game Areas (reusable area definitions)
CREATE TABLE game_areas (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    inclusion_polygons JSONB NOT NULL DEFAULT '[]',
    exclusion_polygons JSONB NOT NULL DEFAULT '[]',
    center_lat DOUBLE PRECISION NOT NULL,
    center_lng DOUBLE PRECISION NOT NULL,
    default_zoom DOUBLE PRECISION DEFAULT 12.0,
    created_by VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Sessions (game instances)
CREATE TABLE sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    room_code VARCHAR(6) NOT NULL UNIQUE,
    status VARCHAR(20) NOT NULL DEFAULT 'waiting',
    game_area_id UUID REFERENCES game_areas(id),
    hiding_period_seconds INTEGER NOT NULL DEFAULT 3600,
    zone_radius_meters DOUBLE PRECISION NOT NULL DEFAULT 804.672,
    hiding_started_at TIMESTAMP WITH TIME ZONE,
    seeking_started_at TIMESTAMP WITH TIME ZONE,
    timer_paused_at TIMESTAMP WITH TIME ZONE,
    paused_time_remaining_seconds INTEGER,
    ended_at TIMESTAMP WITH TIME ZONE,
    winner_id UUID,
    created_by VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    CONSTRAINT valid_status CHECK (status IN ('waiting', 'hiding', 'seeking', 'paused', 'ended'))
);

-- Participants
CREATE TABLE participants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id),
    display_name VARCHAR(100) NOT NULL,
    role VARCHAR(20) NOT NULL DEFAULT 'seeker',
    device_token VARCHAR(255) NOT NULL,
    is_connected BOOLEAN DEFAULT FALSE,
    is_host BOOLEAN DEFAULT FALSE,
    last_location_lat DOUBLE PRECISION,
    last_location_lng DOUBLE PRECISION,
    last_location_at TIMESTAMP WITH TIME ZONE,
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    CONSTRAINT valid_role CHECK (role IN ('hider', 'seeker', 'spectator'))
);

-- Session Questions
CREATE TABLE session_questions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    question_id VARCHAR(50) NOT NULL,
    category VARCHAR(20) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'asked',
    asked_by_participant_id UUID NOT NULL REFERENCES participants(id),
    asked_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    answered_at TIMESTAMP WITH TIME ZONE,
    response_deadline TIMESTAMP WITH TIME ZONE NOT NULL,
    answer_text TEXT,
    answer_photo_url TEXT,
    answer_audio_url TEXT,
    was_test_mode BOOLEAN DEFAULT FALSE,

    CONSTRAINT valid_question_status CHECK (status IN ('pending', 'asked', 'answered', 'expired', 'vetoed')),
    CONSTRAINT valid_category CHECK (category IN ('matching', 'measuring', 'radar', 'thermometer', 'tentacles', 'photo'))
);

-- Hider Cards
CREATE TABLE hider_cards (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    card_id VARCHAR(50) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'in_hand',
    drawn_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    played_at TIMESTAMP WITH TIME ZONE,
    discarded_at TIMESTAMP WITH TIME ZONE,

    CONSTRAINT valid_card_status CHECK (status IN ('in_deck', 'in_hand', 'played', 'discarded'))
);

-- Active Curses
CREATE TABLE active_curses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    card_id VARCHAR(50) NOT NULL,
    curse_type VARCHAR(30) NOT NULL,
    started_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE,
    is_blocking BOOLEAN DEFAULT FALSE,
    condition TEXT,

    CONSTRAINT valid_curse_type CHECK (curse_type IN ('express_route', 'long_shot', 'runner', 'museum'))
);

-- Placed Time Traps
CREATE TABLE placed_time_traps (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    card_id VARCHAR(50) NOT NULL,
    station_id VARCHAR(100) NOT NULL,
    station_name VARCHAR(255) NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    placed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    triggered_at TIMESTAMP WITH TIME ZONE,
    triggered_by_participant_id UUID REFERENCES participants(id)
);

-- Indexes for performance
CREATE INDEX idx_sessions_room_code ON sessions(room_code);
CREATE INDEX idx_sessions_status ON sessions(status);
CREATE INDEX idx_participants_session_id ON participants(session_id);
CREATE INDEX idx_participants_device_token ON participants(device_token);
CREATE INDEX idx_session_questions_session_id ON session_questions(session_id);
CREATE INDEX idx_session_questions_status ON session_questions(status);
CREATE INDEX idx_hider_cards_session_id ON hider_cards(session_id);
CREATE INDEX idx_active_curses_session_id ON active_curses(session_id);
CREATE INDEX idx_placed_time_traps_session_id ON placed_time_traps(session_id);

-- Enable Row Level Security
ALTER TABLE game_areas ENABLE ROW LEVEL SECURITY;
ALTER TABLE sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE session_questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE hider_cards ENABLE ROW LEVEL SECURITY;
ALTER TABLE active_curses ENABLE ROW LEVEL SECURITY;
ALTER TABLE placed_time_traps ENABLE ROW LEVEL SECURITY;

-- RLS Policies

-- Game areas: Anyone can read, creators can update/delete their own
CREATE POLICY "Anyone can view game areas" ON game_areas
    FOR SELECT USING (true);

CREATE POLICY "Authenticated users can create game areas" ON game_areas
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Creators can update their game areas" ON game_areas
    FOR UPDATE USING (created_by = current_setting('request.jwt.claims', true)::json->>'sub'
                      OR created_by = (SELECT device_token FROM participants WHERE user_id = auth.uid() LIMIT 1));

-- Sessions: Anyone can read, creators can update
CREATE POLICY "Anyone can view sessions" ON sessions
    FOR SELECT USING (true);

CREATE POLICY "Anyone can create sessions" ON sessions
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Session creators can update" ON sessions
    FOR UPDATE USING (true);

-- Participants: Session participants can read/write
CREATE POLICY "Anyone can view participants" ON participants
    FOR SELECT USING (true);

CREATE POLICY "Anyone can join sessions" ON participants
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Participants can update themselves" ON participants
    FOR UPDATE USING (true);

CREATE POLICY "Participants can leave" ON participants
    FOR DELETE USING (true);

-- Questions: Session participants can read/write
CREATE POLICY "Session participants can view questions" ON session_questions
    FOR SELECT USING (true);

CREATE POLICY "Seekers can ask questions" ON session_questions
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Hider can answer questions" ON session_questions
    FOR UPDATE USING (true);

-- Cards: Session participants can read/write
CREATE POLICY "Session participants can view cards" ON hider_cards
    FOR SELECT USING (true);

CREATE POLICY "Hider can draw cards" ON hider_cards
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Hider can update cards" ON hider_cards
    FOR UPDATE USING (true);

-- Curses: Session participants can read/write
CREATE POLICY "Session participants can view curses" ON active_curses
    FOR SELECT USING (true);

CREATE POLICY "Session participants can create curses" ON active_curses
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Session participants can remove curses" ON active_curses
    FOR DELETE USING (true);

-- Time traps: Session participants can read/write
CREATE POLICY "Session participants can view traps" ON placed_time_traps
    FOR SELECT USING (true);

CREATE POLICY "Hider can place traps" ON placed_time_traps
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Traps can be triggered" ON placed_time_traps
    FOR UPDATE USING (true);

-- Enable Realtime for relevant tables
ALTER PUBLICATION supabase_realtime ADD TABLE sessions;
ALTER PUBLICATION supabase_realtime ADD TABLE participants;
ALTER PUBLICATION supabase_realtime ADD TABLE session_questions;
ALTER PUBLICATION supabase_realtime ADD TABLE hider_cards;
ALTER PUBLICATION supabase_realtime ADD TABLE active_curses;
