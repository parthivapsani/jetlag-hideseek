-- Storage buckets for photos and audio

-- Create storage buckets
INSERT INTO storage.buckets (id, name, public)
VALUES
    ('question_photos', 'question_photos', true),
    ('question_audio', 'question_audio', true)
ON CONFLICT (id) DO NOTHING;

-- Storage policies for question photos
CREATE POLICY "Anyone can view question photos"
ON storage.objects FOR SELECT
USING (bucket_id = 'question_photos');

CREATE POLICY "Authenticated users can upload question photos"
ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'question_photos');

CREATE POLICY "Users can update their photos"
ON storage.objects FOR UPDATE
USING (bucket_id = 'question_photos');

-- Storage policies for question audio
CREATE POLICY "Anyone can view question audio"
ON storage.objects FOR SELECT
USING (bucket_id = 'question_audio');

CREATE POLICY "Authenticated users can upload question audio"
ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'question_audio');

CREATE POLICY "Users can update their audio"
ON storage.objects FOR UPDATE
USING (bucket_id = 'question_audio');
