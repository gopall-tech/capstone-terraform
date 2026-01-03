-- Create requests table for storing backend requests
CREATE TABLE IF NOT EXISTS requests (
  id SERIAL PRIMARY KEY,
  backend_name VARCHAR(50) NOT NULL,
  ts TIMESTAMP DEFAULT NOW(),
  meta JSONB,
  image BYTEA
);

-- Create index on timestamp for faster queries
CREATE INDEX IF NOT EXISTS idx_requests_ts ON requests(ts DESC);

-- Create index on backend_name for filtering
CREATE INDEX IF NOT EXISTS idx_requests_backend ON requests(backend_name);

-- Insert a test record
INSERT INTO requests (backend_name, meta, image) 
VALUES ('test', '{"message": "Database initialized"}', NULL);

-- Display table structure
\d requests

-- Show recent records
SELECT id, backend_name, ts, meta FROM requests ORDER BY ts DESC LIMIT 5;
