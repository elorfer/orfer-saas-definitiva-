import Redis from 'ioredis';
import * as dotenv from 'dotenv';

dotenv.config();

async function checkRedis() {
  const redisUrl = process.env.REDIS_URL;
  const redisHost = process.env.REDIS_HOST || 'localhost';
  const redisPort = parseInt(process.env.REDIS_PORT || '6379');
  const redisPassword = process.env.REDIS_PASSWORD;

  let redis: Redis;

  try {
    console.log('🔌 Intentando conectar a Redis...');

    if (redisUrl) {
      console.log(`   URL: ${redisUrl.replace(/:[^:@]+@/, ':****@')}`);
      redis = new Redis(redisUrl);
    } else {
      console.log(`   Host: ${redisHost}:${redisPort}`);
      redis = new Redis({
        host: redisHost,
        port: redisPort,
        password: redisPassword,
        retryStrategy: () => null, // No reintentar
        connectTimeout: 5000,
      });
    }

    await redis.ping();
    console.log('✅ Redis conectado correctamente!');

    // Probar operación básica
    await redis.set('test:connection', 'ok', 'EX', 10);
    const testValue = await redis.get('test:connection');
    await redis.del('test:connection');

    if (testValue === 'ok') {
      console.log('✅ Redis funcionando correctamente (test READ/WRITE)');
    }

    await redis.quit();
    console.log('\n✨ Redis está listo para usar!');

  } catch (error: any) {
    console.error('❌ Error conectando a Redis:', error.message);
    console.log('\n💡 Para instalar Redis:');
    console.log('   Windows: https://github.com/microsoftarchive/redis/releases');
    console.log('   macOS: brew install redis && brew services start redis');
    console.log('   Linux: sudo apt install redis-server && sudo systemctl start redis');
    console.log('\n   O usando Docker:');
    console.log('   docker run -d -p 6379:6379 redis:alpine');
    process.exit(1);
  }
}

checkRedis();












