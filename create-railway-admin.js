// Script para crear un admin en Railway
const axios = require('axios');

const RAILWAY_URL = 'https://orfer-saas-definitiva-production.up.railway.app';

async function createAdmin() {
    try {
        console.log('🚀 Creando admin en Railway...');

        const response = await axios.post(`${RAILWAY_URL}/api/v1/auth/register`, {
            email: 'admin@struky.com',
            username: 'admin_struky',
            password: 'Admin123!Struky',
            firstName: 'Admin',
            lastName: 'Struky',
            role: 'admin' // ✅ Ahora el backend acepta esto
        });

        console.log('✅ Admin creado exitosamente en Railway!');
        console.log('\n📋 CREDENCIALES:');
        console.log('   Email: admin@struky.com');
        console.log('   Password: Admin123!Struky');
        console.log('\n🎯 Ahora puedes hacer login en el admin panel con estas credenciales');

    } catch (error) {
        if (error.response) {
            console.error('❌ Error:', error.response.data);
        } else {
            console.error('❌ Error:', error.message);
        }
    }
}

createAdmin();
