const bcrypt = require('bcryptjs');

async function resetPassword() {
  const password = 'AdminReal123!';
  const hash = await bcrypt.hash(password, 12);
  console.log('Hash generado:', hash);
  console.log('\nEjecuta este comando SQL:');
  console.log(`UPDATE users SET password_hash = '${hash}' WHERE email = 'admin@vintagemusic.com';`);
  
  // Verificar que el hash funciona
  const isValid = await bcrypt.compare(password, hash);
  console.log('\nVerificación:', isValid ? '✅ Hash válido' : '❌ Hash inválido');
}

resetPassword().catch(console.error);





