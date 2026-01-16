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
  @ApiOperation({ summary: 'Batería de pruebas SSL para R2' })
  async checkR2Debug() {
    const accountId = process.env.R2_ACCOUNT_ID?.replace(/["']/g, '').trim();
    const domain = `${accountId}.r2.cloudflarestorage.com`;
    const https = require('https');

    const runTest = (name: string, agentOptions: any) => new Promise<{ result: string, details?: string }>((resolve) => {
      const options = {
        hostname: domain,
        port: 443,
        path: '/',
        method: 'HEAD',
        agent: new https.Agent(agentOptions),
      };

      const req = https.request(options, (res: any) => {
        resolve({ result: 'SUCCESS', details: `Status: ${res.statusCode}, Proto: ${res.socket.getProtocol ? res.socket.getProtocol() : 'unknown'}` });
      });

      req.on('error', (e: any) => {
        resolve({ result: 'FAILED', details: e.message });
      });

      req.end();
    });

    // Ejecutar pruebas
    const tests = {
      timestamp: new Date().toISOString(),
      node_version: process.version,
      openssl: process.versions.openssl,
      domain,
      results: {} as any
    };

    // Test 1: Defecto (Inseguro)
    tests.results.test1_default_insecure = await runTest('Default Insecure', { rejectUnauthorized: false });

    // Test 2: Forzar TLS 1.2
    tests.results.test2_force_tls1_2 = await runTest('Force TLS 1.2', {
      rejectUnauthorized: false,
      minVersion: 'TLSv1.2',
      maxVersion: 'TLSv1.2',
      secureProtocol: 'TLSv1_2_method'
    });

    // Test 3: Compatibility Mode (Ciphers antiguos)
    tests.results.test3_compat_ciphers = await runTest('Compat Ciphers', {
      rejectUnauthorized: false,
      ciphers: 'ALL',
      secureOptions: 0x4000000 // SSL_OP_NO_TLSv1_3 (Intentar desactivar 1.3 si falla)
    });

    return tests;
  }
}
