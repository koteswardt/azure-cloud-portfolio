const express = require('express');
const sql = require('mssql');
const { DefaultAzureCredential } = require('@azure/identity');
const { SecretClient } = require('@azure/keyvault-secrets');

const app = express();
app.use(express.json());

app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.header('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') res.sendStatus(200);
  else next();
});

let pool = null;

async function initializeDatabase() {
  try {
    const credential = new DefaultAzureCredential();
    const vaultUrl = 'https://kv-capstone-009.vault.azure.net/';
    const client = new SecretClient(vaultUrl, credential);
    const secret = await client.getSecret('SqlConnectionString');

    const config = {
      server: 'capstone-sql-009.database.windows.net',
      database: 'capstonedb',
      authentication: {
        type: 'azure-active-directory-msi-app-service',
      },
      options: {
        encrypt: true,
        trustServerCertificate: false,
      }
    };

    pool = new sql.ConnectionPool(config);
    await pool.connect();
    console.log('✅ Connected to SQL Database');
  } catch (err) {
    console.error('❌ Database connection error:', err);
  }
}

app.get('/api/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date(),
    region: 'Australia East'
  });
});

app.get('/api/products', async (req, res) => {
  try {
    const result = await pool.request().query('SELECT id, name, price FROM Products');
    res.json(result.recordset);
  } catch (err) {
    console.error('Query error:', err);
    res.status(500).json({ error: 'Failed to fetch products' });
  }
});

const PORT = process.env.PORT || 8080;
initializeDatabase().then(() => {
  app.listen(PORT, () => {
    console.log(`🚀 API running on port ${PORT}`);
  });
});