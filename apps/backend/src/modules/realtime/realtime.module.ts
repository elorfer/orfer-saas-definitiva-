import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { RealtimeGateway } from './realtime.gateway';
import { RealtimeService } from './realtime.service';
import { RealtimeController } from './realtime.controller';
import { PlayHistory } from '../../common/entities/play-history.entity';
import { JwtModule } from '@nestjs/jwt';
import { ConfigModule, ConfigService } from '@nestjs/config';

@Module({
  imports: [
    TypeOrmModule.forFeature([PlayHistory]),
    JwtModule.registerAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (configService: ConfigService) => ({
        secret: configService.get<string>('JWT_SECRET', 'vintage_jwt_secret_2024_ultra_secure'),
        signOptions: {
          expiresIn: configService.get<string>('JWT_EXPIRES_IN', '7d'),
        },
      }),
    }),
    ConfigModule,
  ],
  providers: [RealtimeGateway, RealtimeService],
  controllers: [RealtimeController],
  exports: [RealtimeService, RealtimeGateway],
})
export class RealtimeModule {}

