const { Pool } = require('pg');

const pool = new Pool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT || 5432,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  ssl: { rejectUnauthorized: false }
});

(async () => {
  try {
    console.log('Connecting to:', process.env.DB_HOST, '/', process.env.DB_NAME);

    await pool.query(`
      CREATE TABLE IF NOT EXISTS requests (
        id SERIAL PRIMARY KEY,
        backend_name VARCHAR(50) NOT NULL,
        ts TIMESTAMP DEFAULT NOW(),
        meta JSONB,
        image BYTEA
      )
    `);
    console.log('✅ Table created');

    await pool.query('CREATE INDEX IF NOT EXISTS idx_requests_ts ON requests(ts DESC)');
    await pool.query('CREATE INDEX IF NOT EXISTS idx_requests_backend ON requests(backend_name)');
    console.log('✅ Indexes created');

    const result = await pool.query('SELECT COUNT(*) as count FROM requests');
    console.log('✅ Rows:', result.rows[0].count);

    await pool.end();
    console.log('✅ Database initialized successfully!');
  } catch (err) {
    console.error('❌ Error:', err.message);
    process.exit(1);
  }
})();
