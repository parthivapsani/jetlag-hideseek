-- Teams
CREATE TABLE teams (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    color VARCHAR(20) NOT NULL DEFAULT 'green',
    display_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_teams_session_id ON teams(session_id);

-- Rounds
CREATE TABLE rounds (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    round_number INTEGER NOT NULL DEFAULT 1,
    hider_team_id UUID REFERENCES teams(id),
    seeker_team_id UUID REFERENCES teams(id),
    status VARCHAR(20) NOT NULL DEFAULT 'waiting',
    hiding_started_at TIMESTAMP WITH TIME ZONE,
    seeking_started_at TIMESTAMP WITH TIME ZONE,
    timer_paused_at TIMESTAMP WITH TIME ZONE,
    paused_time_remaining_seconds INTEGER,
    found_at TIMESTAMP WITH TIME ZONE,
    hide_duration_seconds INTEGER,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    CONSTRAINT valid_round_status CHECK (status IN ('waiting', 'hiding', 'seeking', 'endgame', 'found')),
    CONSTRAINT unique_round_per_session UNIQUE (session_id, round_number)
);

CREATE INDEX idx_rounds_session_id ON rounds(session_id);
CREATE INDEX idx_rounds_status ON rounds(status);

-- Modify participants: add team_id
ALTER TABLE participants ADD COLUMN team_id UUID REFERENCES teams(id);

-- Modify sessions: add team-based winner fields
ALTER TABLE sessions ADD COLUMN winning_team_id UUID REFERENCES teams(id);
ALTER TABLE sessions ADD COLUMN winner_override BOOLEAN DEFAULT false;
ALTER TABLE sessions ADD COLUMN total_rounds INTEGER DEFAULT 2;

-- Modify session_questions: add round_id
ALTER TABLE session_questions ADD COLUMN round_id UUID REFERENCES rounds(id);

-- Modify hider_cards: add round_id
ALTER TABLE hider_cards ADD COLUMN round_id UUID REFERENCES rounds(id);

-- Modify active_curses: add round_id
ALTER TABLE active_curses ADD COLUMN round_id UUID REFERENCES rounds(id);

-- Enable RLS on new tables
ALTER TABLE teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds ENABLE ROW LEVEL SECURITY;

-- RLS Policies for teams
CREATE POLICY "Anyone can view teams" ON teams FOR SELECT USING (true);
CREATE POLICY "Anyone can create teams" ON teams FOR INSERT WITH CHECK (true);
CREATE POLICY "Anyone can update teams" ON teams FOR UPDATE USING (true);

-- RLS Policies for rounds
CREATE POLICY "Anyone can view rounds" ON rounds FOR SELECT USING (true);
CREATE POLICY "Anyone can create rounds" ON rounds FOR INSERT WITH CHECK (true);
CREATE POLICY "Anyone can update rounds" ON rounds FOR UPDATE USING (true);

-- Enable Realtime for new tables
ALTER PUBLICATION supabase_realtime ADD TABLE teams;
ALTER PUBLICATION supabase_realtime ADD TABLE rounds;
