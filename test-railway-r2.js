const axios = require('axios');

async function testRailwayR2() {
    try {
        console.log('🧪 Probando si Railway tiene R2 configurado...\n');

        const response = await axios.get(
            'https://orfer-saas-definitiva-production.up.railway.app/api/v1/health'
        );

        console.log('✅ Backend respondió:');
        console.log('Storage:', response.data.storage || 'No especificado');
        console.log('\nRespuesta completa:', JSON.stringify(response.data, null, 2));

        if (response.data.storage === 'Cloudflare R2') {
            console.log('\n✅ R2 ESTÁ CONFIGURADO CORRECTAMENTE');
        } else {
            console.log('\n❌ R2 NO ESTÁ CONFIGURADO - Usando AWS S3 o local');
        }

    } catch (error) {
        console.error('❌ Error:', error.message);
    }
}

testRailwayR2();
