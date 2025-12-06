import axios from 'axios';
import * as dotenv from 'dotenv';

dotenv.config();

const BASE_URL = process.env.API_BASE_URL || 'http://localhost:3001/api/v1';

async function createUserAndTestStreams() {
  console.log('🧪 Creando usuario de prueba y probando Streams...\n');

  try {
    // Paso 1: Crear usuario de prueba
    console.log('1️⃣ Creando usuario de prueba...');
    const testUser = {
      email: 'streamtest@example.com',
      password: 'test123456',
      username: 'streamtest',
      firstName: 'Stream',
      lastName: 'Test',
    };

    let token: string;
    try {
      const registerResponse = await axios.post(`${BASE_URL}/auth/register`, testUser);
      console.log('   ✅ Usuario creado exitosamente!');
      
      // Login automático
      const loginResponse = await axios.post<{ access_token: string }>(
        `${BASE_URL}/auth/login`,
        {
          email: testUser.email,
          password: testUser.password,
        },
      );
      token = loginResponse.data.access_token;
      console.log('   ✅ Login exitoso!');
    } catch (error: any) {
      if (error.response?.status === 409) {
        console.log('   ℹ️  Usuario ya existe, haciendo login...');
        const loginResponse = await axios.post<{ access_token: string }>(
          `${BASE_URL}/auth/login`,
          {
            email: testUser.email,
            password: testUser.password,
          },
        );
        token = loginResponse.data.access_token;
        console.log('   ✅ Login exitoso!');
      } else {
        throw error;
      }
    }

    // Paso 2: Obtener una canción
    console.log('\n2️⃣ Obteniendo canción de prueba...');
    let songId: string;
    let songTitle: string;
    
    try {
      const songsResponse = await axios.get(`${BASE_URL}/public/songs`, {
        params: { limit: 1 },
        headers: { Authorization: `Bearer ${token}` },
      });

      const songs = songsResponse.data?.songs || songsResponse.data || [];
      if (songs.length === 0) {
        console.log('   ⚠️  No hay canciones en la base de datos');
        console.log('   💡 El test necesita al menos una canción para funcionar');
        console.log('   📝 Creando una canción de prueba...');
        
        // Intentar crear una canción (requiere ser artista)
        console.log('   ⚠️  No se puede crear canción sin ser artista');
        console.log('   💡 Por favor crea una canción manualmente o usa una existente');
        return;
      }

      songId = songs[0].id;
      songTitle = songs[0].title || 'N/A';
      console.log(`   ✅ Canción: "${songTitle}"`);
      console.log(`   ID: ${songId}`);
    } catch (error: any) {
      console.log('   ❌ Error obteniendo canciones:', error.response?.data?.message || error.message);
      console.log('   💡 Asegúrate de tener canciones en la base de datos');
      return;
    }

    // Paso 3: Test 1 - Progreso < 30s
    console.log('\n3️⃣ Test 1: Progreso 15s (NO debe registrar)');
    try {
      const response1 = await axios.post(
        `${BASE_URL}/streams/track-progress`,
        {
          songId,
          progressMs: 15000,
          durationMs: 210000,
          volume: 0.8,
          isForeground: true,
        },
        {
          headers: {
            Authorization: `Bearer ${token}`,
            'Content-Type': 'application/json',
          },
        },
      );

      console.log('   ✅ Respuesta:');
      console.log(`      shouldRegisterStream: ${response1.data.shouldRegisterStream}`);
      console.log(`      streamRegistered: ${response1.data.streamRegistered}`);
      
      if (!response1.data.shouldRegisterStream && !response1.data.streamRegistered) {
        console.log('   ✅ CORRECTO: No registró stream (progreso < 30s)');
      }
    } catch (error: any) {
      console.log('   ❌ Error:', error.response?.data?.message || error.message);
    }

    // Esperar un momento
    await new Promise(resolve => setTimeout(resolve, 1000));

    // Paso 4: Test 2 - Progreso ≥ 30s
    console.log('\n4️⃣ Test 2: Progreso 35s (SÍ debe registrar)');
    try {
      const response2 = await axios.post(
        `${BASE_URL}/streams/track-progress`,
        {
          songId,
          progressMs: 35000,
          durationMs: 210000,
          volume: 0.8,
          isForeground: true,
        },
        {
          headers: {
            Authorization: `Bearer ${token}`,
            'Content-Type': 'application/json',
          },
        },
      );

      console.log('   ✅ Respuesta:');
      console.log(`      shouldRegisterStream: ${response2.data.shouldRegisterStream}`);
      console.log(`      streamRegistered: ${response2.data.streamRegistered}`);
      console.log(`      message: ${response2.data.message || 'N/A'}`);
      
      if (response2.data.streamRegistered) {
        console.log('   ✅ CORRECTO: Stream registrado exitosamente! 🎉');
      } else if (response2.data.shouldRegisterStream && !response2.data.streamRegistered) {
        console.log('   ⚠️  Rate limit activo (normal si ya registraste uno recientemente)');
      }
    } catch (error: any) {
      console.log('   ❌ Error:', error.response?.data?.message || error.message);
      if (error.response?.status === 404) {
        console.log('   💡 El songId no existe en la base de datos');
      }
    }

    // Paso 5: Test 3 - Intento duplicado inmediato (rate limit)
    console.log('\n5️⃣ Test 3: Intento duplicado inmediato (rate limit)');
    await new Promise(resolve => setTimeout(resolve, 500));
    
    try {
      const response3 = await axios.post(
        `${BASE_URL}/streams/track-progress`,
        {
          songId,
          progressMs: 45000,
          durationMs: 210000,
          volume: 0.8,
          isForeground: true,
        },
        {
          headers: {
            Authorization: `Bearer ${token}`,
            'Content-Type': 'application/json',
          },
        },
      );

      console.log('   ✅ Respuesta:');
      console.log(`      shouldRegisterStream: ${response3.data.shouldRegisterStream}`);
      console.log(`      streamRegistered: ${response3.data.streamRegistered}`);
      
      if (!response3.data.streamRegistered) {
        console.log('   ✅ CORRECTO: Rate limit funcionando (previene duplicados)');
      }
    } catch (error: any) {
      console.log('   ⚠️  Error esperado (rate limit):', error.response?.data?.message || error.message);
    }

    console.log('\n✨ Pruebas completadas!');
    console.log('\n📊 Verificar en base de datos:');
    console.log('   SELECT * FROM streams ORDER BY created_at DESC LIMIT 5;');
    console.log('   SELECT * FROM user_listening_sessions ORDER BY created_at DESC LIMIT 5;');

  } catch (error: any) {
    console.error('❌ Error:', error.message);
    if (error.response) {
      console.error('   Status:', error.response.status);
      console.error('   Data:', JSON.stringify(error.response.data, null, 2));
    }
    process.exit(1);
  }
}

createUserAndTestStreams();




