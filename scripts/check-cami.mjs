// Simple fetch para verificar usuarios
const response = await fetch('http://localhost:3000/api/users', {
    headers: {
        'Content-Type': 'application/json',
        // Si necesitas token, agrégalo aquí
    }
});

const data = await response.json();
console.log('Total usuarios:', data.total);

// Buscar Cami
const cami = data.users.find(u =>
    u.email?.includes('cami') ||
    u.first_name?.toLowerCase().includes('cami')
);

if (cami) {
    console.log('\n✅ Usuario encontrado:');
    console.log('Email:', cami.email);
    console.log('Subscription Status:', cami.subscription_status);
    console.log('Subscription Source:', cami.subscription_source || 'NO DEFINIDO');
    console.log('RevenueCat Customer ID:', cami.revenuecat_customer_id || 'N/A');
    console.log('Premium Expires At:', cami.premium_expires_at);
    console.log('\nInterpretación:');
    if (cami.subscription_source === 'manual') {
        console.log('  ✅ Correctamente marcado como MANUAL (activado desde admin)');
    } else if (cami.subscription_source === 'revenuecat') {
        console.log('  ⚠️ Marcado como REVENUECAT (activado desde app)');
    } else {
        console.log('  ❌ SIN FUENTE DEFINIDA (necesita migración)');
    }
} else {
    console.log('❌ Usuario Cami no encontrado');
}
