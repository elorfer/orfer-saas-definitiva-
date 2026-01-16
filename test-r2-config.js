const axios = require('axios');

async function testR2Config() {
    try {
        console.log('🧪 Probando configuración de R2...\n');

        const response = await axios.get(
            'https://orfer-saas-definitiva-production.up.railway.app/api/v1/health'
        );

        console.log('✅ Backend está activo');
        console.log('Response:', response.data);

    } catch (error) {
        console.error('❌ Error:', error.message);
    }
}

testR2Config();
