CREATE TABLE api_usage (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    api_type VARCHAR(50) NOT NULL,
    session_id UUID REFERENCES sessions(id),
    estimated_cost_cents INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_api_usage_created ON api_usage(created_at);
CREATE INDEX idx_api_usage_type ON api_usage(api_type);

ALTER TABLE api_usage ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can view api usage" ON api_usage FOR SELECT USING (true);
CREATE POLICY "Anyone can create api usage" ON api_usage FOR INSERT WITH CHECK (true);
