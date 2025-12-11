import axios from 'axios';
import * as dotenv from 'dotenv';

dotenv.config();

const BASE_URL = process.env.API_BASE_URL || 'http://localhost:3001/api/v1';

interface LoginResponse {
  access_token: string;
  user: any;
}

async function testStreamsEndpoint() {
  console.log('🧪 Probando sistema de Streams...\n');

  try {
    // Paso 1: Obtener token JWT (necesitas un usuario válido)
    console.log('1️⃣ Intentando login...');
    console.log('   (Nota: Necesitas tener un usuario registrado en la base de datos)');
    
    // Intentar login con credenciales por defecto o de prueba
    // Si no tienes usuario, el script te dirá cómo crear uno
    const loginData = {
      email: process.env.TEST_USER_EMAIL || 'test@example.com',
      password: process.env.TEST_USER_PASSWORD || 'password123',
    };

    let token: string;
    try {
      const loginResponse = await axios.post<LoginResponse>(
        `${BASE_URL}/auth/login`,
        loginData,
      );
      token = loginResponse.data.access_token;
      console.log('   ✅ Login exitoso!');
      console.log(`   Usuario: ${loginResponse.data.user?.email || 'N/A'}`);
    } catch (error: any) {
      if (error.response?.status === 401) {
        console.log('   ⚠️  Login falló: Credenciales inválidas');
        console.log('\n💡 Para crear un usuario de prueba:');
        console.log('   POST /api/v1/auth/register');
        console.log('   {');
        console.log('     "email": "test@example.com",');
        console.log('     "password": "password123",');
        console.log('     "username": "testuser",');
        console.log('     "firstName": "Test",');
        console.log('     "lastName": "User"');
        console.log('   }');
        console.log('\n   O usa las variables de entorno:');
        console.log('   TEST_USER_EMAIL=tu@email.com');
        console.log('   TEST_USER_PASSWORD=tupassword');
        return;
      }
      throw error;
    }

    // Paso 2: Verificar que necesitamos un songId válido
    console.log('\n2️⃣ Obteniendo una canción de prueba...');
    
    // Intentar obtener canciones públicas
    let songId: string;
    try {
      const songsResponse = await axios.get(`${BASE_URL}/public/songs`, {
        params: { limit: 1 },
        headers: { Authorization: `Bearer ${token}` },
      });

      const songs = songsResponse.data?.songs || songsResponse.data || [];
      if (songs.length === 0) {
        console.log('   ⚠️  No hay canciones disponibles');
        console.log('   💡 Necesitas tener al menos una canción en la base de datos');
        return;
      }

      songId = songs[0].id;
      console.log(`   ✅ Canción encontrada: "${songs[0].title}" (${songId})`);
    } catch (error: any) {
      console.log('   ⚠️  Error obteniendo canciones:', error.message);
      console.log('   💡 Usando songId de prueba (puede fallar si no existe)');
      songId = 'test-song-id'; // Fallback
    }

    // Paso 3: Probar track-progress con progreso < 30s (no debe registrar)
    console.log('\n3️⃣ Test 1: Progreso < 30s (NO debe registrar stream)');
    try {
      const response1 = await axios.post(
        `${BASE_URL}/streams/track-progress`,
        {
          songId,
          progressMs: 15000, // 15 segundos
          durationMs: 210000, // 3.5 minutos
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

      console.log('   ✅ Respuesta recibida:');
      console.log(`      shouldRegisterStream: ${response1.data.shouldRegisterStream}`);
      console.log(`      streamRegistered: ${response1.data.streamRegistered}`);
      
      if (!response1.data.shouldRegisterStream) {
        console.log('   ✅ Correcto: No registra stream (progreso < 30s)');
      } else {
        console.log('   ⚠️  Inesperado: Debería ser false');
      }
    } catch (error: any) {
      console.log('   ❌ Error:', error.response?.data?.message || error.message);
    }

    // Paso 4: Probar track-progress con progreso ≥ 30s (debe registrar)
    console.log('\n4️⃣ Test 2: Progreso ≥ 30s (SÍ debe registrar stream)');
    try {
      const response2 = await axios.post(
        `${BASE_URL}/streams/track-progress`,
        {
          songId,
          progressMs: 35000, // 35 segundos
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

      console.log('   ✅ Respuesta recibida:');
      console.log(`      shouldRegisterStream: ${response2.data.shouldRegisterStream}`);
      console.log(`      streamRegistered: ${response2.data.streamRegistered}`);
      console.log(`      message: ${response2.data.message || 'N/A'}`);
      
      if (response2.data.streamRegistered) {
        console.log('   ✅ Correcto: Stream registrado exitosamente!');
      } else if (response2.data.shouldRegisterStream && !response2.data.streamRegistered) {
        console.log('   ⚠️  Rate limit: Puede ser que ya registraste un stream recientemente');
      }
    } catch (error: any) {
      console.log('   ❌ Error:', error.response?.data?.message || error.message);
      if (error.response?.status === 404) {
        console.log('   💡 El songId no existe. Necesitas una canción válida.');
      }
    }

    // Paso 5: Verificar streams en DB (opcional)
    console.log('\n5️⃣ Verificando streams registrados...');
    console.log('   (Puedes verificar en la base de datos ejecutando:)');
    console.log('   SELECT * FROM streams ORDER BY created_at DESC LIMIT 5;');

    console.log('\n✨ Pruebas completadas!\n');

  } catch (error: any) {
    console.error('❌ Error general:', error.message);
    if (error.response) {
      console.error('   Status:', error.response.status);
      console.error('   Data:', JSON.stringify(error.response.data, null, 2));
    }
    process.exit(1);
  }
}

// Verificar que axios esté disponible
try {
  testStreamsEndpoint();
} catch (error: any) {
  if (error.message.includes('Cannot find module')) {
    console.log('⚠️  Instalando axios...');
    console.log('   Ejecuta: npm install axios');
    process.exit(1);
  }
  throw error;
}












