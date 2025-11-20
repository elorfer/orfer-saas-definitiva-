const { Client } = require('pg');
const bcrypt = require('bcryptjs');

async function createAdminUser() {
  const client = new Client({
    host: 'localhost',
    port: 5432,
    database: 'vintage_music',
    user: 'vintage_user',
    password: 'vintage_password_2024',
  });

  try {
    await client.connect();
    console.log('✅ Conectado a la base de datos');

    // Verificar si el usuario admin existe
    const checkResult = await client.query(
      'SELECT id, email, role, is_active FROM users WHERE email = $1',
      ['admin@vintagemusic.com']
    );

    const password = 'AdminReal123!';
    const hash = await bcrypt.hash(password, 12);

    if (checkResult.rows.length > 0) {
      // Usuario existe, actualizar contraseña
      console.log('✅ Usuario admin encontrado, actualizando contraseña...');
      const updateResult = await client.query(
        'UPDATE users SET password_hash = $1, role = $2, is_active = $3, is_verified = $4 WHERE email = $5',
        [hash, 'admin', true, true, 'admin@vintagemusic.com']
      );
      console.log(`✅ Contraseña actualizada. Filas afectadas: ${updateResult.rowCount}`);
    } else {
      // Usuario no existe, crearlo
      console.log('✅ Usuario admin no existe, creándolo...');
      const insertResult = await client.query(
        `INSERT INTO users (email, username, password_hash, first_name, last_name, role, is_verified, is_active) 
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
        ['admin@vintagemusic.com', 'admin', hash, 'Admin', 'Vintage', 'admin', true, true]
      );
      console.log('✅ Usuario admin creado exitosamente');
    }

    // Mostrar credenciales
    console.log('\n═══════════════════════════════════════════════════');
    console.log('🔐 CREDENCIALES DE ADMIN');
    console.log('═══════════════════════════════════════════════════');
    console.log('Email:    admin@vintagemusic.com');
    console.log('Password: AdminReal123!');
    console.log('═══════════════════════════════════════════════════\n');

  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  } finally {
    await client.end();
  }
}

createAdminUser();



