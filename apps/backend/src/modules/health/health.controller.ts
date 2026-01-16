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
  @ApiOperation({ summary: 'Batería de pruebas SSL para R2 (incluyendo Fetch)' })
  async checkR2Debug() {
    const accountId = process.env.R2_ACCOUNT_ID?.replace(/["']/g, '').trim();
    const domain = `${accountId}.r2.cloudflarestorage.com`;
    const endpoint = `https://${domain}`;
    const https = require('https');

    // Helper para HTTPS legacy
    const runHttpsTest = (name: string, agentOptions: any) => new Promise<{ result: string, details?: string }>((resolve) => {
      const options = {
        hostname: domain,
        port: 443,
        path: '/',
        method: 'HEAD',
        agent: new https.Agent(agentOptions),
        timeout: 5000
      };

      const req = https.request(options, (res) => {
        resolve({ result: 'SUCCESS', details: `Status: ${res.statusCode}` });
      });

      req.on('error', (e) => {
        resolve({ result: 'FAILED', details: e.message });
      });

      req.on('timeout', () => {
        req.destroy();
        resolve({ result: 'TIMEOUT', details: 'Socket timeout' });
      });

      req.end();
    });

    // Helper para Fetch Moderno
    const runFetchTest = async () => {
      try {
        const res = await fetch(endpoint, { method: 'HEAD' });
        return { result: 'SUCCESS', details: `Status: ${res.status} (via global fetch)` };
      } catch (e) {
        return { result: 'FAILED', details: e.message };
      }
    };

    const tests = {
      timestamp: new Date().toISOString(),
      node_version: process.version,
      results: {} as any
    };

    try {
      // Test 1: HTTPS Nativo (El que falla siempre)
      tests.results.test1_legacy_https = await runHttpsTest('Legacy HTTPS', { rejectUnauthorized: false });

      // Test 2: HTTPS + TLS 1.2
      tests.results.test2_tls12 = await runHttpsTest('TLS 1.2', {
        rejectUnauthorized: false,
        minVersion: 'TLSv1.2',
        maxVersion: 'TLSv1.2'
      });

      // Test 3: FETCH Nativo (Undici/Moderno)
      // Si este funciona, migramos el SDK a usar fetch-http-handler
      if (typeof fetch !== 'undefined') {
        tests.results.test3_native_fetch = await runFetchTest();
      } else {
        tests.results.test3_native_fetch = { result: 'SKIPPED', details: 'Fetch not available in this Node version' };
      }

    } catch (err) {
      tests.results.error_global = err.message;
    }

    return tests;
  }
}
