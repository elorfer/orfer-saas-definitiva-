import { NestFactory } from '@nestjs/core';
import { AppModule } from '../src/app.module';
import { UserRole, User } from '../src/common/entities/user.entity';
import { Repository } from 'typeorm';
import { getRepositoryToken } from '@nestjs/typeorm';
import * as bcrypt from 'bcryptjs';

async function bootstrap() {
  console.log('🚀 Iniciando script para crear Admin en Producción...');
  
  // Usar el contexto de la aplicación para acceder a TypeORM
  const app = await NestFactory.createApplicationContext(AppModule);
  const userRepository = app.get<Repository<User>>(getRepositoryToken(User));

  const email = 'admin@struky.com';
  const password = 'StrukyAdminProduccion2024!';
  const username = 'admin_produccion';

  console.log(`🔍 Verificando si el usuario ${email} ya existe...`);
  
  const existingUser = await userRepository.findOne({ where: { email } });

  if (existingUser) {
    console.log('⚠️ El usuario ya existe. Actualizando a rol ADMIN y cambiando contraseña...');
    const passwordHash = await bcrypt.hash(password, 12);
    
    await userRepository.update(existingUser.id, {
      role: UserRole.ADMIN,
      passwordHash: passwordHash,
      isVerified: true,
      isActive: true
    });
    console.log('✅ Usuario actualizado correctamente.');
  } else {
    console.log('🆕 Creando nuevo usuario administrador...');
    const passwordHash = await bcrypt.hash(password, 12);
    
    const newUser = userRepository.create({
      email,
      username,
      passwordHash,
      firstName: 'Admin',
      lastName: 'Struky',
      role: UserRole.ADMIN,
      isVerified: true,
      isActive: true
    });
    
    await userRepository.save(newUser);
    console.log('✅ Nuevo administrador creado exitosamente.');
  }

  console.log('-------------------------------------------');
  console.log(`📧 Email: ${email}`);
  console.log(`🔑 Password: ${password}`);
  console.log('-------------------------------------------');
  console.log('🚀 Ya puedes intentar loguearte en tu Admin de Vercel.');

  await app.close();
}

bootstrap();
