// Script para crear un nuevo admin maestro en Railway
const axios = require('axios');

const RAILWAY_URL = 'https://orfer-saas-definitiva-production.up.railway.app';

async function createAdmin() {
    try {
        console.log('🚀 Creando nuevo admin maestro en Railway...');

        const response = await axios.post(`${RAILWAY_URL}/api/v1/auth/register`, {
            email: 'master@struky.com',
            username: 'struky_master',
            password: 'StrukyAdmin2026!',
            firstName: 'Master',
            lastName: 'Struky',
            role: 'admin'
        });

        console.log('✅ Nuevo admin maestro creado exitosamente!');
        console.log('\n📋 NUEVAS CREDENCIALES:');
        console.log('   Email: master@struky.com');
        console.log('   Username: struky_master');
        console.log('   Password: StrukyAdmin2026!');
        console.log('\n🎯 Ya puedes usar estas credenciales en Flutter y el panel Admin.');

    } catch (error) {
        if (error.response) {
            console.error('❌ Error:', error.response.data);
        } else {
            console.error('❌ Error:', error.message);
        }
    }
}

createAdmin();
