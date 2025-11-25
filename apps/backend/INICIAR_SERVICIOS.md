# 🚀 Cómo Iniciar los Servicios

## ⚠️ Problema Actual

El servidor NestJS está intentando conectarse a PostgreSQL pero no puede porque:
- Docker Desktop no está corriendo, O
- PostgreSQL no está disponible en `localhost:5432`

---

## ✅ Solución Rápida

### Opción 1: Iniciar Docker Desktop (Recomendado)

1. **Abre Docker Desktop** desde el menú de inicio
2. **Espera** a que Docker Desktop termine de iniciar (verás el ícono en la bandeja del sistema)
3. **Inicia los servicios:**
   ```bash
   cd "C:\app definitiva"
   docker-compose up -d postgres redis
   ```

4. **Verifica que están corriendo:**
   ```bash
   docker ps
   ```

5. **Inicia el servidor:**
   ```bash
   cd apps/backend
   npm run start:dev
   ```

---

### Opción 2: PostgreSQL Local

Si tienes PostgreSQL instalado localmente:

1. **Inicia el servicio de PostgreSQL:**
   ```powershell
   # Si está como servicio de Windows
   Start-Service postgresql-x64-16
   # O el nombre de tu servicio PostgreSQL
   ```

2. **Verifica que está corriendo:**
   ```bash
   # Desde PowerShell
   Test-NetConnection -ComputerName localhost -Port 5432
   ```

3. **Crea la base de datos** (si no existe):
   ```sql
   CREATE DATABASE vintage_music;
   CREATE USER vintage_user WITH PASSWORD 'vintage_password_2024';
   GRANT ALL PRIVILEGES ON DATABASE vintage_music TO vintage_user;
   ```

4. **Inicia el servidor:**
   ```bash
   cd apps/backend
   npm run start:dev
   ```

---

## 🔍 Verificar Estado

### Verificar Docker
```bash
docker ps
# Debe mostrar: vintage-music-postgres y vintage-music-redis
```

### Verificar PostgreSQL
```bash
# Con Docker
docker exec vintage-music-postgres psql -U vintage_user -d vintage_music -c "SELECT version();"

# O localmente
psql -U vintage_user -d vintage_music -c "SELECT version();"
```

### Verificar Redis
```bash
# Con Docker
docker exec vintage-music-redis redis-cli ping
# Debe responder: PONG
```

---

## 📝 Configuración Actual

Según tu `.env`:
- **Host:** `localhost`
- **Puerto:** `5432`
- **Base de datos:** `vintage_music`
- **Usuario:** `vintage_user`
- **Contraseña:** `vintage_password_2024`

---

## 🎯 Próximos Pasos

1. ✅ Iniciar Docker Desktop
2. ✅ Iniciar PostgreSQL y Redis con `docker-compose up -d postgres redis`
3. ✅ Verificar que están corriendo
4. ✅ Iniciar el servidor NestJS
5. ✅ Probar el endpoint de upload

---

**Nota:** El servidor NestJS seguirá intentando conectarse automáticamente. Una vez que PostgreSQL esté disponible, se conectará automáticamente.










