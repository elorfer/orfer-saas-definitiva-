import { Controller, Get } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse } from '@nestjs/swagger';

@ApiTags('health')
@Controller('health')
export class HealthController {
  @Get()
  @ApiOperation({ summary: 'Health check del servidor' })
  @ApiResponse({ status: 200, description: 'Servidor funcionando correctamente' })
  check() {
    // Verificar si Sharp está disponible
    let sharpAvailable = false;
    let sharpVersion = 'N/A';
    try {
      const sharp = require('sharp');
      sharpAvailable = true;
      sharpVersion = sharp.versions?.sharp || 'unknown';
    } catch (error) {
      sharpAvailable = false;
    }

    return {
      status: 'ok',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      environment: process.env.NODE_ENV || 'development',
      services: {
        sharp: {
          available: sharpAvailable,
          version: sharpVersion,
        },
        storage: process.env.R2_ACCOUNT_ID ? 'Cloudflare R2' : 'AWS S3',
      },
    };
  }
}























