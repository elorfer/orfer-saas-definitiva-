#!/usr/bin/env node

const { spawn } = require('child_process');
const path = require('path');

console.log('🚀 Iniciando Admin Panel...');

// Cambiar al directorio del admin
const adminDir = path.join(__dirname, '../../admin');

// Iniciar el admin panel
const adminProcess = spawn('npm', ['run', 'dev'], {
  cwd: adminDir,
  stdio: 'inherit',
  shell: true
});

adminProcess.on('error', (error) => {
  console.error('❌ Error al iniciar el admin panel:', error);
});

adminProcess.on('close', (code) => {
  console.log(`📱 Admin panel cerrado con código: ${code}`);
});

// Manejar cierre del proceso
process.on('SIGINT', () => {
  console.log('\n🛑 Cerrando admin panel...');
  adminProcess.kill('SIGINT');
  process.exit(0);
});

process.on('SIGTERM', () => {
  console.log('\n🛑 Cerrando admin panel...');
  adminProcess.kill('SIGTERM');
  process.exit(0);
});


