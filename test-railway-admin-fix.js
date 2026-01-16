// Script para verificar que Railway tiene el fix del rol admin
const axios = require('axios');

const RAILWAY_URL = 'https://orfer-saas-definitiva-production.up.railway.app';

async function testAdminRoleCreation() {
    try {
        console.log('🧪 Probando creación de admin en Railway actualizado...\n');

        // Intentar crear un admin de prueba
        const testEmail = `admin_test_${Date.now()}@struky.com`;
        const response = await axios.post(`${RAILWAY_URL}/api/v1/auth/register`, {
            email: testEmail,
            username: `admin_test_${Date.now()}`,
            password: 'TestAdmin123!',
            firstName: 'Admin',
            lastName: 'Test',
            role: 'admin' // ✅ Esto debería funcionar ahora
        });

        const user = response.data.user;

        console.log('✅ USUARIO CREADO EXITOSAMENTE!\n');
        console.log('📋 Datos del usuario:');
        console.log(`   Email: ${user.email}`);
        console.log(`   Username: ${user.username}`);
        console.log(`   Rol: ${user.role}`);
        console.log(`   Activo: ${user.is_active}`);

        if (user.role === 'admin') {
            console.log('\n🎉 ¡ÉXITO! El fix del rol admin está funcionando en Railway');
            console.log('✅ Ahora puedes crear admins desde el admin panel');
        } else {
            console.log('\n⚠️ WARNING: El usuario se creó pero con rol:', user.role);
            console.log('   Puede que Railway necesite reiniciarse');
        }

    } catch (error) {
        if (error.response) {
            console.error('❌ Error:', error.response.data);
        } else {
            console.error('❌ Error:', error.message);
        }
    }
}

testAdminRoleCreation();
