const { Client } = require('pg');
const bcrypt = require('bcryptjs');

async function resetAdminPassword() {
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

    // Generar hash de la contraseña
    const password = 'AdminReal123!';
    const hash = await bcrypt.hash(password, 12);
    console.log('✅ Hash generado:', hash.substring(0, 30) + '...');

    // Actualizar contraseña
    const result = await client.query(
      'UPDATE users SET password_hash = $1 WHERE email = $2',
      [hash, 'admin@vintagemusic.com']
    );

    console.log(`✅ Contraseña actualizada. Filas afectadas: ${result.rowCount}`);

    // Verificar que el hash funciona
    const verifyResult = await client.query(
      'SELECT password_hash FROM users WHERE email = $1',
      ['admin@vintagemusic.com']
    );

    if (verifyResult.rows.length > 0) {
      const storedHash = verifyResult.rows[0].password_hash;
      const isValid = await bcrypt.compare(password, storedHash);
      console.log('✅ Verificación:', isValid ? 'Hash válido' : 'Hash inválido');
    }

  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  } finally {
    await client.end();
  }
}

resetAdminPassword();


