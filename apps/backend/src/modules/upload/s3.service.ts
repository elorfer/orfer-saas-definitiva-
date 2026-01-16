import { Injectable, BadRequestException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { S3Client, PutObjectCommand, DeleteObjectCommand, GetObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import * as path from 'path';
import { NodeHttpHandler } from '@aws-sdk/node-http-handler';
import * as https from 'https';
import { v4 as uuidv4 } from 'uuid';

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
      const rawAccountId = this.configService.get<string>('R2_ACCOUNT_ID');
      const accountId = rawAccountId ? rawAccountId.replace(/["']/g, '').trim() : '';

      const rawAccessKey = this.configService.get<string>('R2_ACCESS_KEY_ID');
      const accessKeyId = rawAccessKey ? rawAccessKey.replace(/["']/g, '').trim() : '';

      const rawSecretKey = this.configService.get<string>('R2_SECRET_ACCESS_KEY');
      const secretAccessKey = rawSecretKey ? rawSecretKey.replace(/["']/g, '').trim() : '';

      this.bucketName = this.configService.get<string>('R2_BUCKET_NAME') || 'struky-media';

      // 2. Región 'us-east-1' es la más compatible para clientes S3 genéricos conectando a R2
      this.region = 'us-east-1';

      const endpoint = `https://${accountId}.r2.cloudflarestorage.com`;
      console.log(`🔌 R2 Connection Init: ${endpoint} (Region: ${this.region})`);

      this.s3Client = new S3Client({
        region: this.region,
        endpoint: endpoint,
        credentials: {
          accessKeyId: accessKeyId,
          secretAccessKey: secretAccessKey,
        },
        forcePathStyle: true,
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

  async uploadFile(
    file: Express.Multer.File,
    folder: string,
    userId: string,
  ): Promise<{ url: string; key: string }> {
    try {
      const fileExtension = path.extname(file.originalname);
      const fileName = `${uuidv4()}${fileExtension}`;
      const key = `${folder}/${userId}/${fileName}`;

      const useR2 = this.configService.get<string>('R2_ACCOUNT_ID');

      if (useR2) {
        // 🔥 NUEVO APPROACH: Upload directo con fetch (bypass AWS SDK SSL issues)
        const rawAccountId = this.configService.get<string>('R2_ACCOUNT_ID');
        const accountId = rawAccountId ? rawAccountId.replace(/["']/g, '').trim() : '';
        const rawAccessKey = this.configService.get<string>('R2_ACCESS_KEY_ID');
        const accessKeyId = rawAccessKey ? rawAccessKey.replace(/["']/g, '').trim() : '';
        const rawSecretKey = this.configService.get<string>('R2_SECRET_ACCESS_KEY');
        const secretAccessKey = rawSecretKey ? rawSecretKey.replace(/["']/g, '').trim() : '';

        const endpoint = `https://${accountId}.r2.cloudflarestorage.com`;
        const uploadUrl = `${endpoint}/${this.bucketName}/${key}`;

        console.log(`🚀 Direct R2 Upload (fetch): ${uploadUrl}`);

        // Upload directo con fetch (sin AWS SDK)
        const response = await fetch(uploadUrl, {
          method: 'PUT',
          headers: {
            'Content-Type': file.mimetype,
            'x-amz-acl': 'public-read',
            'x-amz-meta-originalname': file.originalname,
            'x-amz-meta-uploadedby': userId,
            'x-amz-meta-uploadedat': new Date().toISOString(),
          },
          body: new Uint8Array(file.buffer),
          // @ts-ignore - Node fetch tiene opciones adicionales
          agent: new https.Agent({
            rejectUnauthorized: false,
          }),
        });

        if (!response.ok) {
          const errorText = await response.text();
          throw new Error(`R2 upload failed: ${response.status} - ${errorText}`);
        }

        console.log(`✅ R2 Upload Success: ${key}`);

        // Generar URL pública
        const r2PublicDomain = this.configService.get<string>('R2_PUBLIC_DOMAIN');
        let url: string;
        if (r2PublicDomain) {
          const cleanDomain = r2PublicDomain.replace(/["']/g, '').trim();
          url = `https://${cleanDomain}/${key}`;
        } else {
          url = `https://pub-${accountId}.r2.dev/${key}`;
        }

        return { url, key };
      } else {
        // Fallback a AWS S3 con SDK tradicional
        const command = new PutObjectCommand({
          Bucket: this.bucketName,
          Key: key,
          Body: file.buffer,
          ContentType: file.mimetype,
          ACL: 'public-read',
          Metadata: {
            originalName: file.originalname,
            uploadedBy: userId,
            uploadedAt: new Date().toISOString(),
          },
        });

        await this.s3Client.send(command);

        const url = `https://${this.bucketName}.s3.${this.region}.amazonaws.com/${key}`;
        return { url, key };
      }
    } catch (error) {
      console.error('❌ Upload Error:', error);
      throw new BadRequestException(`Error al subir archivo: ${error.message}`);
    }
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

  async generatePresignedUploadUrl(
    key: string,
    contentType: string,
    expiresIn: number = 3600,
  ): Promise<string> {
    try {
      const command = new PutObjectCommand({
        Bucket: this.bucketName,
        Key: key,
        ContentType: contentType,
      });

      return await getSignedUrl(this.s3Client, command, { expiresIn });
    } catch (error) {
      throw new BadRequestException(`Error al generar URL de subida: ${error.message}`);
    }
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
