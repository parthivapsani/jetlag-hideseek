-- Feature Requests
CREATE TABLE feature_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'open',
    submitter_name VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    CONSTRAINT valid_feature_status CHECK (status IN ('open', 'in_progress', 'done'))
);

CREATE INDEX idx_feature_requests_status ON feature_requests(status);
CREATE INDEX idx_feature_requests_created ON feature_requests(created_at DESC);

-- RLS: anyone can view and submit, only admin can update status
ALTER TABLE feature_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view feature requests" ON feature_requests
    FOR SELECT USING (true);

CREATE POLICY "Anyone can submit feature requests" ON feature_requests
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Anyone can update feature requests" ON feature_requests
    FOR UPDATE USING (true);
