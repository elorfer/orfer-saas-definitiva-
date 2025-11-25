const { Client } = require('pg');
const bcrypt = require('bcryptjs');

async function verifyAdmin() {
  const client = new Client({
    host: 'localhost',
    port: 5432,
    database: 'vintage_music',
    user: 'vintage_user',
    password: 'vintage_password_2024',
  });

  try {
    await client.connect();
    console.log('✅ Conectado a la base de datos\n');

    // Buscar usuario admin
    const result = await client.query(
      'SELECT id, email, username, role, is_active, is_verified, password_hash FROM users WHERE email = $1',
      ['admin@vintagemusic.com']
    );

    if (result.rows.length === 0) {
      console.log('❌ Usuario admin NO encontrado');
      console.log('Creando usuario admin...\n');
      
      const password = 'AdminReal123!';
      const hash = await bcrypt.hash(password, 12);
      
      const insertResult = await client.query(
        `INSERT INTO users (email, username, password_hash, first_name, last_name, role, is_verified, is_active) 
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING id`,
        ['admin@vintagemusic.com', 'admin', hash, 'Admin', 'Vintage', 'admin', true, true]
      );
      
      console.log('✅ Usuario admin creado exitosamente');
      console.log('\n═══════════════════════════════════════════════════');
      console.log('🔐 CREDENCIALES DE ADMIN');
      console.log('═══════════════════════════════════════════════════');
      console.log('Email:    admin@vintagemusic.com');
      console.log('Password: AdminReal123!');
      console.log('═══════════════════════════════════════════════════\n');
    } else {
      const user = result.rows[0];
      console.log('✅ Usuario admin encontrado:');
      console.log('   Email:', user.email);
      console.log('   Username:', user.username);
      console.log('   Role:', user.role);
      console.log('   Active:', user.is_active);
      console.log('   Verified:', user.is_verified);
      
      // Probar contraseña
      const testPassword = 'AdminReal123!';
      const passwordMatch = await bcrypt.compare(testPassword, user.password_hash);
      
      console.log('\n🔍 Verificación de contraseña:');
      console.log('   Password "AdminReal123!":', passwordMatch ? '✅ VÁLIDA' : '❌ INVÁLIDA');
      
      if (!passwordMatch) {
        console.log('\n⚠️  La contraseña no coincide. Actualizando...');
        const newHash = await bcrypt.hash(testPassword, 12);
        await client.query(
          'UPDATE users SET password_hash = $1 WHERE email = $2',
          [newHash, 'admin@vintagemusic.com']
        );
        console.log('✅ Contraseña actualizada');
        
        // Verificar de nuevo
        const verifyResult = await client.query(
          'SELECT password_hash FROM users WHERE email = $1',
          ['admin@vintagemusic.com']
        );
        const finalMatch = await bcrypt.compare(testPassword, verifyResult.rows[0].password_hash);
        console.log('   Verificación final:', finalMatch ? '✅ OK' : '❌ ERROR');
      }
      
      console.log('\n═══════════════════════════════════════════════════');
      console.log('🔐 CREDENCIALES DE ADMIN');
      console.log('═══════════════════════════════════════════════════');
      console.log('Email:    admin@vintagemusic.com');
      console.log('Password: AdminReal123!');
      console.log('═══════════════════════════════════════════════════\n');
    }

  } catch (error) {
    console.error('❌ Error:', error.message);
    console.error(error);
    process.exit(1);
  } finally {
    await client.end();
  }
}

verifyAdmin();






