// Script para verificar el estado del admin en Railway
const axios = require('axios');

const RAILWAY_URL = 'https://orfer-saas-definitiva-production.up.railway.app';

async function checkAdmin() {
    try {
        console.log('🔍 Intentando login para verificar...');

        const loginResponse = await axios.post(`${RAILWAY_URL}/api/v1/auth/login`, {
            email: 'admin@struky.com',
            password: 'Admin123!Struky'
        });

        console.log('✅ Login exitoso!');
        console.log('📋 Usuario:', loginResponse.data.user);

    } catch (error) {
        if (error.response) {
            console.log('❌ Error de login:', error.response.data);
            console.log('📊 Status:', error.response.status);

            if (error.response.status === 401) {
                console.log('\n🔍 DIAGNÓSTICO:');
                console.log('   - Usuario puede no existir');
                console.log('   - Usuario puede estar inactivo (isActive = false)');
                console.log('   - Contraseña puede ser incorrecta');
                console.log('\n💡 Voy a crear otro admin con isActive = true...');
            }
        } else {
            console.error('❌ Error:', error.message);
        }
    }
}

checkAdmin();
