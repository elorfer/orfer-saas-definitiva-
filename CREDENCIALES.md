# 👤 CREDENCIALES DE ACCESO

## ✅ Base de datos poblada exitosamente

Tu base de datos ahora tiene usuarios de prueba. Puedes usar cualquiera de estas credenciales para acceder:

---

## 🔐 Usuarios creados:

### 1️⃣ Usuario Administrador Maestro ✅ (NUEVO)
```
Email: master@struky.com
Username: struky_master
Password: StrukyAdmin2026!
Rol: Admin
```
**Este es el acceso principal recomendado para producción.**

### 2️⃣ Usuario Administrador Secundario
```
Email: admin@struky.com
Username: adminstruky
Password: admin123
Rol: Admin
```
**Acceso alternativo.**


### 2️⃣ Usuario de Prueba
```
Email: test@struky.com
Username: testuser
Password: admin123
Rol: User (Premium activo)
```

---

## 📊 Servicios activos:

### PostgreSQL 🐘
```
Host: localhost
Port: 5432
Database: vintage_music
Usuario: vintage_user
Contraseña: vintage_password_2024
```

### Redis 🔴
```
Host: localhost
Port: 6379
```

---

## 🚀 Próximos pasos:

1. **Acceder a la app**: Usa `test@struky.com` / `admin123` en el login
2. **Panel admin**: Usa `admin@struky.com` / `admin123` para acceder al panel administrativo
3. **Subir canciones**: Desde el panel admin puedes subir nuevas canciones y artistas

---

## 📝 Notas importantes:

- La contraseña para todos los usuarios de prueba es: **admin123**
- Los usuarios tienen premium activo por defecto
- Puedes cambiar las contraseñas desde el panel de administración

---

## 🛠️ Comandos útiles:

### Ver usuarios en la base de datos:
```powershell
docker exec -i vintage-music-postgres psql -U vintage_user -d vintage_music -c "SELECT email, username, role FROM users;"
```

### Ver canciones:
```powershell
docker exec -i vintage-music-postgres psql -U vintage_user -d vintage_music -c "SELECT title, artists.stage_name as artist FROM songs LEFT JOIN artists ON songs.artist_id = artists.id LIMIT 10;"
```

### Detener servicios:
```powershell
.\stop-services.ps1
```

### Iniciar servicios:
```powershell
.\start-services.ps1
```
