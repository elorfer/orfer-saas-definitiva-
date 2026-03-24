import { NestFactory } from '@nestjs/core';
import { AppModule } from '../src/app.module';
import { User } from '../src/common/entities/user.entity';
import { Repository } from 'typeorm';
import { getRepositoryToken } from '@nestjs/typeorm';

async function bootstrap() {
  console.log('🔍 Diagnosticando usuario admin...');
  
  const app = await NestFactory.createApplicationContext(AppModule);
  const userRepository = app.get<Repository<User>>(getRepositoryToken(User));

  const email = 'admin@struky.com';
  const user = await userRepository.findOne({ where: { email } });

  if (user) {
    console.log('✅ Usuario encontrado:');
    console.log(`- Email: ${user.email}`);
    console.log(`- Username: ${user.username}`);
    console.log(`- Role: ${user.role}`);
    console.log(`- Is Verified: ${user.isVerified}`);
    console.log(`- Is Active: ${user.isActive}`);
    console.log(`- Password Hash starts with: ${user.passwordHash.substring(0, 10)}...`);
  } else {
    console.log('❌ Usuario No encontrado en la base de datos.');
  }

  await app.close();
}

bootstrap();
