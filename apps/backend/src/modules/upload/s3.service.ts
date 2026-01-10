import { Injectable, BadRequestException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { S3Client, PutObjectCommand, DeleteObjectCommand, GetObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import * as path from 'path';
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
      // Configuración para Cloudflare R2
      const accountId = this.configService.get<string>('R2_ACCOUNT_ID');
      this.bucketName = this.configService.get<string>('R2_BUCKET_NAME') || 'struky-audio';
      this.region = 'auto'; // R2 usa 'auto'

      this.s3Client = new S3Client({
        region: this.region,
        endpoint: `https://${accountId}.r2.cloudflarestorage.com`,
        credentials: {
          accessKeyId: this.configService.get<string>('R2_ACCESS_KEY_ID'),
          secretAccessKey: this.configService.get<string>('R2_SECRET_ACCESS_KEY'),
        },
      });

      console.log('✅ Storage: Usando Cloudflare R2');
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

      // Generar URL pública según el provider
      const useR2 = this.configService.get<string>('R2_ACCOUNT_ID');
      let url: string;

      if (useR2) {
        // URL pública de Cloudflare R2
        const r2PublicDomain = this.configService.get<string>('R2_PUBLIC_DOMAIN');
        if (r2PublicDomain) {
          url = `https://${r2PublicDomain}/${key}`;
        } else {
          // Usar dominio público por defecto (necesitas configurar en Cloudflare)
          const accountId = this.configService.get<string>('R2_ACCOUNT_ID');
          url = `https://pub-${accountId}.r2.dev/${key}`;
        }
      } else {
        // URL de S3
        url = `https://${this.bucketName}.s3.${this.region}.amazonaws.com/${key}`;
      }

      return { url, key };
    } catch (error) {
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









