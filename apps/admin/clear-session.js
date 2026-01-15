// ========================================
// SCRIPT PARA LIMPIAR SESIONES DE NEXTAUTH
// ========================================
// Ejecutar en la consola del navegador (F12 → Console)
// ========================================

// Borrar todas las cookies de NextAuth
document.cookie.split(";").forEach(function (c) {
    document.cookie = c.replace(/^ +/, "").replace(/=.*/, "=;expires=" + new Date().toUTCString() + ";path=/");
});

// Limpiar localStorage
localStorage.clear();

// Limpiar sessionStorage
sessionStorage.clear();

console.log("✅ Sesiones limpiadas. Recarga la página (F5)");

// ========================================
// Después de ejecutar esto, recarga el navegador
// ========================================
