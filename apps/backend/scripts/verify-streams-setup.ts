import { Client } from 'pg';
import Redis from 'ioredis';
import * as dotenv from 'dotenv';

dotenv.config();

async function verifySetup() {
  console.log('🔍 Verificando configuración del sistema de Streams...\n');

  // Verificar PostgreSQL
  console.log('1️⃣ Verificando PostgreSQL...');
  const pgClient = new Client({
    connectionString: process.env.DATABASE_URL || 'postgresql://vintage_user:vintage_password_2024@localhost:5432/vintage_music',
    ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false,
  });

  try {
    await pgClient.connect();
    
    // Verificar tablas
    const tablesResult = await pgClient.query(`
      SELECT table_name 
      FROM information_schema.tables 
      WHERE table_schema = 'public' 
      AND table_name IN ('streams', 'user_listening_sessions', 'songs', 'artists', 'users')
      ORDER BY table_name
    `);

    console.log('   ✅ Tablas encontradas:');
    tablesResult.rows.forEach(row => {
      console.log(`      ✓ ${row.table_name}`);
    });

    // Verificar índices
    const indexesResult = await pgClient.query(`
      SELECT indexname 
      FROM pg_indexes 
      WHERE schemaname = 'public' 
      AND indexname LIKE '%stream%' OR indexname LIKE '%session%'
      ORDER BY indexname
    `);

    if (indexesResult.rows.length > 0) {
      console.log('\n   ✅ Índices encontrados:');
      indexesResult.rows.forEach(row => {
        console.log(`      ✓ ${row.indexname}`);
      });
    }

    await pgClient.end();
  } catch (error: any) {
    console.error('   ❌ Error:', error.message);
  }

  // Verificar Redis
  console.log('\n2️⃣ Verificando Redis...');
  const redisUrl = process.env.REDIS_URL;
  const redisHost = process.env.REDIS_HOST || 'localhost';
  const redisPort = parseInt(process.env.REDIS_PORT || '6379');
  const redisPassword = process.env.REDIS_PASSWORD;

  let redis: Redis;

  try {
    if (redisUrl) {
      redis = new Redis(redisUrl);
    } else {
      redis = new Redis({
        host: redisHost,
        port: redisPort,
        password: redisPassword,
        connectTimeout: 5000,
      });
    }

    await redis.ping();
    console.log('   ✅ Redis conectado');

    // Probar rate limiting
    const testKey = 'test:rate_limit:user123:song456';
    await redis.setex(testKey, 30, '1');
    const exists = await redis.exists(testKey);
    await redis.del(testKey);

    if (exists) {
      console.log('   ✅ Rate limiting funcional');
    }

    await redis.quit();
  } catch (error: any) {
    console.error('   ❌ Error:', error.message);
  }

  // Verificar módulo NestJS
  console.log('\n3️⃣ Verificando módulo NestJS...');
  try {
    const fs = require('fs');
    const path = require('path');
    
    const modulePath = path.join(__dirname, '../src/modules/streams/streams.module.ts');
    const servicePath = path.join(__dirname, '../src/modules/streams/streams.service.ts');
    const controllerPath = path.join(__dirname, '../src/modules/streams/streams.controller.ts');
    
    if (fs.existsSync(modulePath)) {
      console.log('   ✅ streams.module.ts existe');
    }
    if (fs.existsSync(servicePath)) {
      console.log('   ✅ streams.service.ts existe');
    }
    if (fs.existsSync(controllerPath)) {
      console.log('   ✅ streams.controller.ts existe');
    }
  } catch (error: any) {
    console.error('   ❌ Error:', error.message);
  }

  console.log('\n✨ Verificación completada!');
  console.log('\n📝 Próximos pasos:');
  console.log('   1. Reinicia el servidor NestJS para cargar el módulo StreamsModule');
  console.log('   2. Prueba el endpoint: POST /api/v1/streams/track-progress');
  console.log('   3. Revisa la documentación en: src/modules/streams/STREAMS_IMPLEMENTATION.md');
}

verifySetup();




















