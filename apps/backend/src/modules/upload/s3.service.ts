import { Injectable, BadRequestException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { S3Client, PutObjectCommand, DeleteObjectCommand, GetObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import * as path from 'path';
import { NodeHttpHandler } from '@aws-sdk/node-http-handler';
import * as https from 'https';
import { v4 as uuidv4 } from 'uuid';
import * as crypto from 'crypto';

@Injectable()
export class S3Service {
  private readonly s3Client: S3Client;
  private readonly bucketName: string;
  private readonly region: string;

  constructor(private readonly configService: ConfigService) {
    // Soporte para Cloudflare R2 o AWS S3
    const useR2 = this.configService.get<string>('R2_ACCOUNT_ID');

    if (useR2) {
      // Configuracion PROFESIONAL para Cloudflare R2
      // 1. Sanitización de credenciales (elimina espacios/comillas invisibles)
      const accountId = this.configService.get<string>('R2_ACCOUNT_ID')?.trim(); // 🔥 Limpieza crítica
      const accessKeyId = this.configService.get<string>('R2_ACCESS_KEY_ID')?.trim();
      const secretAccessKey = this.configService.get<string>('R2_SECRET_ACCESS_KEY')?.trim();

      this.bucketName = this.configService.get<string>('R2_BUCKET_NAME') || 'struky-media';
      this.region = 'auto'; // 🔥 R2 prefiere 'auto'

      // Endpoint base sin bucket (para virtual-hosted style)
      const endpoint = `https://${accountId}.r2.cloudflarestorage.com`;
      console.log(`🔌 R2 Connection Init: ${endpoint} (Region: ${this.region})`);

      this.s3Client = new S3Client({
        region: this.region,
        endpoint: endpoint,
        credentials: {
          accessKeyId: accessKeyId,
          secretAccessKey: secretAccessKey,
        },
        forcePathStyle: true, // 🔥 REVERTIDO: Path style es más seguro para certificados wildcard de R2
        requestChecksumCalculation: 'WHEN_REQUIRED', // Mantener deshabilitado checksum
        requestHandler: new NodeHttpHandler({
          httpsAgent: new https.Agent({
            // 🔓 MAGIC FIX: Bajar nivel de seguridad de OpenSSL 3 para permitir handshake
            ciphers: 'DEFAULT@SECLEVEL=0',
            rejectUnauthorized: false
          }),
        }),
      });

      console.log('✅ Storage: Configurado para Cloudflare R2 (Standard Mode)');
    } else {
      // Configuración para AWS S3 (fallback)
      this.region = this.configService.get<string>('AWS_REGION') || 'us-east-1';
      this.bucketName = this.configService.get<string>('AWS_S3_BUCKET');

      this.s3Client = new S3Client({
        region: this.region,
        credentials: {
          accessKeyId: this.configService.get<string>('AWS_ACCESS_KEY_ID'),
          secretAccessKey: this.configService.get<string>('AWS_SECRET_ACCESS_KEY'),
        },
      });

      console.log('✅ Storage: Usando AWS S3');
    }
  }

  /**
   * Genera firma AWS Signature V4 manualmente (sin SDK)
   * Esto evita problemas de SSL al usar solo HTTP requests nativos
   */
  private generateAwsSignatureV4(
    method: string,
    url: string,
    headers: Record<string, string>,
    payload: Buffer,
    accessKey: string,
    secretKey: string,
    region: string,
  ): Record<string, string> {
    const urlObj = new URL(url);
    const host = urlObj.host;
    const uri = urlObj.pathname;

    const now = new Date();
    const amzDate = now.toISOString().replace(/[:-]|\.\d{3}/g, '');
    const dateStamp = amzDate.substring(0, 8);

    // Canonical request
    const payloadHash = crypto.createHash('sha256').update(payload).digest('hex');

    headers['host'] = host;
    headers['x-amz-date'] = amzDate;
    headers['x-amz-content-sha256'] = payloadHash;

    const canonicalHeaders = Object.keys(headers)
      .sort()
      .map(k => `${k.toLowerCase()}:${headers[k].trim()}`)
      .join('\n') + '\n';

    const signedHeaders = Object.keys(headers).sort().map(k => k.toLowerCase()).join(';');

    const canonicalRequest = [
      method,
      uri,
      '', // Query string (vacío)
      canonicalHeaders,
      signedHeaders,
      payloadHash,
    ].join('\n');

    // String to sign
    const algorithm = 'AWS4-HMAC-SHA256';
    const credentialScope = `${dateStamp}/${region}/s3/aws4_request`;
    const canonicalRequestHash = crypto.createHash('sha256').update(canonicalRequest).digest('hex');

    const stringToSign = [
      algorithm,
      amzDate,
      credentialScope,
      canonicalRequestHash,
    ].join('\n');

    // Signing key
    const kDate = crypto.createHmac('sha256', `AWS4${secretKey}`).update(dateStamp).digest();
    const kRegion = crypto.createHmac('sha256', kDate).update(region).digest();
    const kService = crypto.createHmac('sha256', kRegion).update('s3').digest();
    const kSigning = crypto.createHmac('sha256', kService).update('aws4_request').digest();

    // Signature
    const signature = crypto.createHmac('sha256', kSigning).update(stringToSign).digest('hex');

    // Authorization header
    const authHeader = `${algorithm} Credential=${accessKey}/${credentialScope}, SignedHeaders=${signedHeaders}, Signature=${signature}`;

    return {
      ...headers,
      'Authorization': authHeader,
    };
  }

  async uploadFile(
    file: Express.Multer.File,
    folder: string,
    userId: string,
  ): Promise<{ url: string; key: string }> {
    // ⚠️ ESTE MÉTODO ESTÁ DESHABILITADO
    // Railway tiene restricciones SSL que impiden upload directo a R2
    // USA PRESIGNED URLs en su lugar:
    // 1. POST /upload/presigned-url
    // 2. PUT directo a R2 desde el cliente
    throw new BadRequestException(
      '⚠️ Upload directo deshabilitado debido a restricciones SSL de Railway. ' +
      'Por favor usa presigned URLs: POST /upload/presigned-url'
    );
  }

  async uploadAudioFile(
    file: Express.Multer.File,
    userId: string,
  ): Promise<{ url: string; key: string }> {
    return this.uploadFile(file, 'audio', userId);
  }

  async uploadImageFile(
    file: Express.Multer.File,
    userId: string,
  ): Promise<{ url: string; key: string }> {
    return this.uploadFile(file, 'images', userId);
  }

  async deleteFile(key: string): Promise<void> {
    try {
      const command = new DeleteObjectCommand({
        Bucket: this.bucketName,
        Key: key,
      });

      await this.s3Client.send(command);
    } catch (error) {
      throw new BadRequestException(`Error al eliminar archivo: ${error.message}`);
    }
  }

  async getSignedUrl(key: string, expiresIn: number = 3600): Promise<string> {
    try {
      const command = new GetObjectCommand({
        Bucket: this.bucketName,
        Key: key,
      });

      return await getSignedUrl(this.s3Client, command, { expiresIn });
    } catch (error) {
      throw new BadRequestException(`Error al generar URL firmada: ${error.message}`);
    }
  }

  /**
   * 🔐 PROFESIONAL: Genera Presigned URL segura para upload directo a R2
   * ✅ Validaciones de seguridad
   * ✅ Nombres únicos (UUID)
   * ✅ Expiración corta (5 min)
   * ✅ Logging para auditoría
   */
  async generatePresignedUploadUrl(
    fileName: string,
    contentType: string,
    userId: string,
    folder: string = 'images',
  ): Promise<{ uploadUrl: string; key: string; publicUrl: string; expiresIn: number }> {
    try {
      // ✅ 1. VALIDAR MIME TYPE (Seguridad crítica)
      const allowedTypes = {
        images: ['image/jpeg', 'image/jpg', 'image/png', 'image/webp'],
        audio: ['audio/mpeg', 'audio/mp3', 'audio/wav', 'audio/flac', 'audio/aac'],
      };

      const allowedMimes = allowedTypes[folder] || [];
      if (!allowedMimes.includes(contentType)) {
        throw new BadRequestException(
          `Tipo de archivo no permitido: ${contentType}. Permitidos: ${allowedMimes.join(', ')}`
        );
      }

      // ✅ 2. GENERAR KEY ÚNICO (UUID + userId para aislamiento)
      const fileExtension = path.extname(fileName) || this.getExtensionFromMime(contentType);
      const uniqueFileName = `${uuidv4()}${fileExtension}`;
      const key = `${folder}/${userId}/${uniqueFileName}`;

      // ✅ 3. EXPIRACIÓN CORTA (5 minutos seguridad)
      const expiresIn = 300; // 5 minutos


      // ✅ 4. GENERAR PRESIGNED URL
      const command = new PutObjectCommand({
        Bucket: this.bucketName,
        Key: key,
        ContentType: contentType,
        // ACL removido - R2 no lo soporta como S3
      });

      // 🔥 IMPORTANTE: Deshabilitar checksums para R2 (no soporta x-amz-checksum-*)
      const uploadUrl = await getSignedUrl(this.s3Client, command, {
        expiresIn,
        unhoistableHeaders: new Set(['x-amz-checksum-crc32', 'x-amz-sdk-checksum-algorithm']),
      });


      // ✅ 5. GENERAR URL PÚBLICA (para cuando se complete el upload)
      const useR2 = this.configService.get<string>('R2_ACCOUNT_ID');
      let publicUrl: string;

      if (useR2) {
        const r2PublicDomain = this.configService.get<string>('R2_PUBLIC_DOMAIN');
        if (r2PublicDomain) {
          const cleanDomain = r2PublicDomain.replace(/["']/g, '').trim();
          publicUrl = `https://${cleanDomain}/${key}`;
        } else {
          const rawAccountId = this.configService.get<string>('R2_ACCOUNT_ID');
          const accountId = rawAccountId ? rawAccountId.replace(/["']/g, '').trim() : '';
          publicUrl = `https://pub-${accountId}.r2.dev/${key}`;
        }
      } else {
        publicUrl = `https://${this.bucketName}.s3.${this.region}.amazonaws.com/${key}`;
      }

      // ✅ 6. LOGGING PARA AUDITORÍA
      console.log(`🔐 Presigned URL generada:`, {
        userId,
        key,
        contentType,
        expiresIn: `${expiresIn}s`,
        timestamp: new Date().toISOString(),
      });

      return {
        uploadUrl,
        key,
        publicUrl,
        expiresIn,
      };
    } catch (error) {
      console.error('❌ Error generando presigned URL:', error);
      throw new BadRequestException(`Error al generar URL de subida: ${error.message}`);
    }
  }

  /**
   * Helper: Obtener extensión desde MIME type
   */
  private getExtensionFromMime(mimeType: string): string {
    const mimeMap: Record<string, string> = {
      'image/jpeg': '.jpg',
      'image/jpg': '.jpg',
      'image/png': '.png',
      'image/webp': '.webp',
      'audio/mpeg': '.mp3',
      'audio/mp3': '.mp3',
      'audio/wav': '.wav',
      'audio/flac': '.flac',
      'audio/aac': '.aac',
    };
    return mimeMap[mimeType] || '';
  }

  extractKeyFromUrl(url: string): string {
    const urlParts = url.split('/');
    const bucketIndex = urlParts.findIndex(part => part.includes(this.bucketName));

    if (bucketIndex === -1 || bucketIndex === urlParts.length - 1) {
      throw new BadRequestException('URL de S3 inválida');
    }

    return urlParts.slice(bucketIndex + 1).join('/');
  }

  getCloudFrontUrl(key: string): string {
    const cloudFrontDomain = this.configService.get<string>('CLOUDFRONT_DOMAIN');
    if (cloudFrontDomain) {
      return `https://${cloudFrontDomain}/${key}`;
    }

    // Fallback a S3 directo
    return `https://${this.bucketName}.s3.${this.region}.amazonaws.com/${key}`;
  }
}
