-- Make room_code longer to support nanoid (21 chars)
ALTER TABLE sessions ALTER COLUMN room_code TYPE VARCHAR(30);
