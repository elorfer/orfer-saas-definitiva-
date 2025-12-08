import axios from 'axios';
import * as dotenv from 'dotenv';

dotenv.config();

const BASE_URL = process.env.API_BASE_URL || 'http://localhost:3001/api/v1';

async function testStreamsClean() {
  console.log('🧪 Test limpio del sistema de Streams...\n');

  // Login
  const loginResponse = await axios.post<{ access_token: string }>(
    `${BASE_URL}/auth/login`,
    {
      email: 'streamtest@example.com',
      password: 'test123456',
    },
  );
  const token = loginResponse.data.access_token;
  console.log('✅ Login exitoso\n');

  // Obtener canción
  const songsResponse = await axios.get(`${BASE_URL}/public/songs`, {
    params: { limit: 1 },
    headers: { Authorization: `Bearer ${token}` },
  });
  const song = (songsResponse.data?.songs || songsResponse.data || [])[0];
  const songId = song.id;
  console.log(`📀 Canción: "${song.title}"\n`);

  // Test: Simular reproducción completa
  console.log('▶️  Simulando reproducción...\n');

  // t=0s - Inicio
  console.log('t=0s: Iniciando reproducción...');
  await axios.post(
    `${BASE_URL}/streams/track-progress`,
    {
      songId,
      progressMs: 0,
      durationMs: song.duration * 1000,
      volume: 0.8,
      isForeground: true,
    },
    { headers: { Authorization: `Bearer ${token}` } },
  );
  console.log('   ✅ Sesión creada\n');
  await new Promise(r => setTimeout(r, 500));

  // t=15s - Aún no cuenta
  console.log('t=15s: Progreso intermedio...');
  const r15 = await axios.post(
    `${BASE_URL}/streams/track-progress`,
    {
      songId,
      progressMs: 15000,
      durationMs: song.duration * 1000,
      volume: 0.8,
      isForeground: true,
    },
    { headers: { Authorization: `Bearer ${token}` } },
  );
  console.log(`   shouldRegisterStream: ${r15.data.shouldRegisterStream}`);
  console.log(`   streamRegistered: ${r15.data.streamRegistered}`);
  console.log('   ✅ Correcto: No registra (< 30s)\n');
  await new Promise(r => setTimeout(r, 500));

  // t=35s - Debe registrar
  console.log('t=35s: Progreso ≥ 30s (DEBE REGISTRAR)...');
  const r35 = await axios.post(
    `${BASE_URL}/streams/track-progress`,
    {
      songId,
      progressMs: 35000,
      durationMs: song.duration * 1000,
      volume: 0.8,
      isForeground: true,
    },
    { headers: { Authorization: `Bearer ${token}` } },
  );
  console.log(`   shouldRegisterStream: ${r35.data.shouldRegisterStream}`);
  console.log(`   streamRegistered: ${r35.data.streamRegistered}`);
  console.log(`   message: ${r35.data.message || 'N/A'}`);
  
  if (r35.data.streamRegistered) {
    console.log('   ✅ CORRECTO: Stream registrado! 🎉\n');
  } else {
    console.log('   ⚠️  No se registró. Revisando lógica...\n');
  }

  // Verificar en DB
  console.log('📊 Verificando en base de datos...');
  console.log('   Ejecuta: SELECT * FROM streams WHERE song_id = \'' + songId + '\' ORDER BY created_at DESC LIMIT 1;');
  console.log('   Ejecuta: SELECT * FROM user_listening_sessions WHERE song_id = \'' + songId + '\';');
}

testStreamsClean().catch(console.error);






