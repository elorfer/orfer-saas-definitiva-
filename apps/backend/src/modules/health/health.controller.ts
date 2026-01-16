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

  @Get('r2-debug')
  @ApiOperation({ summary: 'Diagnosticar conexión R2 en profundidad' })
  async checkR2Debug() {
    const accountId = process.env.R2_ACCOUNT_ID?.replace(/["']/g, '').trim();
    const domain = `${accountId}.r2.cloudflarestorage.com`;

    return new Promise((resolve) => {
      const results = {
        step1_dns: 'Pending',
        step2_tcp: 'Pending',
        step3_ssl: 'Pending',
        details: [] as string[],
        error: null as any
      };

      // Paso 1: DNS
      require('dns').lookup(domain, (err, address) => {
        if (err) {
          results.step1_dns = 'FAILED';
          results.details.push(`DNS Error: ${err.message}`);
          resolve(results);
          return;
        }
        results.step1_dns = `SUCCESS (${address})`;

        // Paso 2: TCP Socket
        const socket = new (require('net').Socket)();
        socket.setTimeout(5000);

        socket.connect(443, address, () => {
          results.step2_tcp = 'SUCCESS';
          socket.destroy();

          // Paso 3: HTTPS Request (Native Node.js)
          const https = require('https');
          const options = {
            hostname: domain,
            port: 443,
            path: '/',
            method: 'HEAD',
            rejectUnauthorized: false // Ignoramos validación para probar solo el handshake
          };

          const req = https.request(options, (res) => {
            results.step3_ssl = `SUCCESS (Status: ${res.statusCode})`;
            results.details.push(`Headers: ${JSON.stringify(res.headers)}`);
            resolve(results);
          });

          req.on('error', (e) => {
            results.step3_ssl = `FAILED: ${e.message}`;
            results.error = e.message;
            if ((e as any).opensslErrorStack) {
              results.details.push(`OpenSSL Stack: ${(e as any).opensslErrorStack}`);
            }
            resolve(results);
          });

          req.end();
        });

        socket.on('error', (err) => {
          results.step2_tcp = `FAILED: ${err.message}`;
          resolve(results);
        });

        socket.on('timeout', () => {
          results.step2_tcp = 'TIMEOUT';
          socket.destroy();
          resolve(results);
        });
      });
    });
  }
}























