-- Script SQL para limpiar sesiones de escucha
-- Ejecutar con: psql -U postgres -d vintage_music -f clear-sessions.sql

DELETE FROM user_listening_sessions;
SELECT 'Sesiones limpiadas exitosamente' as resultado;
