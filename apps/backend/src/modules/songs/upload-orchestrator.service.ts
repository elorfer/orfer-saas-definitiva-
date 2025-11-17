import {
  Injectable,
  BadRequestException,
  NotFoundException,
  Logger,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { v4 as uuidv4 } from 'uuid';
import { InjectQueue } from '@nestjs/bull';
import { Queue } from 'bull';

import { SongUpload, UploadStatus } from '../../common/entities/song-upload.entity';
import { LocalStorageService } from './local-storage.service';
import { CoversStorageService } from '../covers/covers-storage.service';
import { CompensationService } from './compensation.service';

export interface UploadRequest {
  uploadId?: string; // ID opcional del cliente para idempotencia
  audioFile: Express.Multer.File;
  coverFile?: Express.Multer.File;
  title: string;
  artistId: string;
  albumId?: string;
  genreId?: string;
  status?: 'draft' | 'pending' | 'published' | 'rejected';
  duration?: number;
  userId: string;
}

export interface UploadResult {
  uploadId: string;
  status: UploadStatus;
  jobId?: string;
  message: string;
}

/**
 * Orquestador principal para el flujo de subida de canciones
 * Maneja idempotencia, tracking y envío a cola de procesamiento
 */
@Injectable()
export class UploadOrchestratorService {
  private readonly logger = new Logger(UploadOrchestratorService.name);
  private readonly isDevelopment = process.env.NODE_ENV !== 'production';

  constructor(
    @InjectRepository(SongUpload)
    private readonly uploadRepository: Repository<SongUpload>,
    private readonly localStorageService: LocalStorageService,
    private readonly coversStorageService: CoversStorageService,
    private readonly compensationService: CompensationService,
    @InjectQueue('song-upload') private readonly uploadQueue: Queue,
  ) {}

  /**
   * Inicia el proceso de subida de canción
   * 1. Verifica idempotencia
   * 2. Crea registro de tracking
   * 3. Sube archivos temporalmente
   * 4. Envía job a cola de procesamiento
   * 5. Responde inmediatamente con 202
   */
  async initiateUpload(request: UploadRequest): Promise<UploadResult> {
    const startTime = Date.now();
    this.logger.log('═══════════════════════════════════════════════════════════');
    this.logger.log('🚀 INICIANDO PROCESO DE SUBIDA DE CANCIÓN');
    this.logger.log(`👤 Usuario: ${request.userId}`);
    this.logger.log(`📝 Título: ${request.title}`);
    this.logger.log('═══════════════════════════════════════════════════════════');

    // Paso 1: Generar o validar uploadId para idempotencia
    const uploadId = request.uploadId || this.generateUploadId();
    this.logger.log(`🆔 Upload ID: ${uploadId}`);

    // Paso 2: Verificar idempotencia - si ya existe un upload con este ID
    const existingUpload = await this.uploadRepository.findOne({
      where: { uploadId },
    });

    if (existingUpload) {
      this.logger.log(`♻️ Upload existente encontrado (idempotencia): ${uploadId}`);
      
      // Si ya está completado, retornar resultado
      if (existingUpload.status === UploadStatus.COMPLETED) {
        return {
          uploadId: existingUpload.uploadId,
          status: UploadStatus.COMPLETED,
          message: 'Upload ya completado anteriormente',
        };
      }

      // Si está en proceso, retornar estado actual
      if (existingUpload.status === UploadStatus.PROCESSING || existingUpload.status === UploadStatus.PENDING) {
        return {
          uploadId: existingUpload.uploadId,
          status: existingUpload.status,
          jobId: existingUpload.jobId,
          message: 'Upload ya en proceso',
        };
      }

      // Si falló, permitir reintento actualizando el registro
      if (existingUpload.status === UploadStatus.FAILED) {
        this.logger.log(`🔄 Reintentando upload fallido: ${uploadId}`);
        await this.uploadRepository.update(
          { uploadId },
          {
            status: UploadStatus.PENDING,
            error: null,
            retryCount: existingUpload.retryCount + 1,
          },
        );
      }
    }

    // Paso 3: Crear registro de tracking
    let uploadRecord: SongUpload;
    if (existingUpload) {
      uploadRecord = await this.uploadRepository.findOne({
        where: { uploadId },
      });
    } else {
      uploadRecord = this.uploadRepository.create({
        uploadId,
        userId: request.userId,
        status: UploadStatus.PENDING,
        title: request.title,
        artistId: request.artistId,
        albumId: request.albumId,
        genreId: request.genreId,
        retryCount: 0,
        compensationApplied: false,
      });
      uploadRecord = await this.uploadRepository.save(uploadRecord);
      this.logger.log(`✅ Registro de tracking creado: ${uploadRecord.id}`);
    }

    // Paso 4: Subir archivos temporalmente (rápido, sin procesamiento pesado)
    let audioFileKey: string | undefined;
    let coverFileKey: string | undefined;

    try {
      this.logger.log('📤 Subiendo archivo de audio (temporal)...');
      const audioResult = await this.localStorageService.uploadAudioFile(
        request.audioFile,
        request.userId,
      );
      audioFileKey = audioResult.key;
      this.logger.log(`✅ Audio subido: ${audioFileKey}`);

      if (request.coverFile) {
        this.logger.log('📤 Subiendo portada (temporal)...');
        const coverResult = await this.coversStorageService.uploadCoverImage(
          request.coverFile,
          request.userId,
        );
        coverFileKey = coverResult.key;
        this.logger.log(`✅ Portada subida: ${coverFileKey}`);
      }

      // Actualizar registro con las claves de archivos
      await this.uploadRepository.update(uploadRecord.id, {
        audioFileKey,
        coverFileKey,
        status: UploadStatus.PENDING,
      });
    } catch (error) {
      this.logger.error(`❌ Error al subir archivos: ${error.message}`);
      
      // Limpiar archivos subidos si falló
      await this.compensationService.cleanupFiles({
        audioFileKey,
        coverFileKey,
      });

      // Actualizar registro con error
      await this.uploadRepository.update(uploadRecord.id, {
        status: UploadStatus.FAILED,
        error: `Error al subir archivos: ${error.message}`,
      });

      throw new BadRequestException(`Error al subir archivos: ${error.message}`);
    }

    // Paso 5: Enviar job a cola de procesamiento asíncrono
    this.logger.log('📤 Preparando para enviar job a cola...');
    try {
      if (!this.uploadQueue) {
        throw new Error('Queue no está inicializada');
      }
      this.logger.log('✅ Queue está inicializada, agregando job...');
      
      // Agregar timeout manual para evitar que se quede colgado
      const jobData = {
        uploadId: uploadRecord.uploadId,
        audioFileKey,
        coverFileKey,
        title: request.title,
        artistId: request.artistId,
        albumId: request.albumId,
        genreId: request.genreId,
        status: request.status,
        duration: request.duration,
        userId: request.userId,
      };
      
      this.logger.log(`📝 Datos del job: ${JSON.stringify({ ...jobData, audioFileKey: audioFileKey?.substring(0, 20) + '...' })}`);
      
      const jobOptions = {
        jobId: `upload-${uploadRecord.uploadId}`, // ID único del job
        attempts: 3, // Reintentos automáticos
        backoff: {
          type: 'exponential' as const,
          delay: 5000, // 5 segundos iniciales
        },
        removeOnComplete: {
          age: 24 * 3600, // Mantener jobs completados por 24 horas
          count: 1000, // Mantener últimos 1000 jobs
        },
        removeOnFail: {
          age: 7 * 24 * 3600, // Mantener jobs fallidos por 7 días
        },
      };
      
      this.logger.log('⏳ Ejecutando uploadQueue.add() con timeout de 10 segundos...');
      
      // Timeout manual de 10 segundos
      const jobPromise = this.uploadQueue.add(
        'process-song-upload',
        jobData,
        jobOptions,
      );
      
      const timeoutPromise = new Promise((_, reject) => {
        setTimeout(() => {
          reject(new Error('Timeout: No se recibió respuesta de Redis después de 10 segundos'));
        }, 10000);
      });
      
      const job = await Promise.race([jobPromise, timeoutPromise]) as any;

      // Actualizar registro con jobId
      await this.uploadRepository.update(uploadRecord.id, {
        jobId: job.id.toString(),
        status: UploadStatus.PROCESSING,
      });

      const elapsed = Date.now() - startTime;
      this.logger.log(`✅ Job enviado a cola: ${job.id}`);
      this.logger.log(`⏱️ Tiempo total: ${elapsed}ms`);
      this.logger.log('═══════════════════════════════════════════════════════════');

      return {
        uploadId: uploadRecord.uploadId,
        status: UploadStatus.PROCESSING,
        jobId: job.id.toString(),
        message: 'Upload iniciado, procesando en segundo plano',
      };
    } catch (error) {
      this.logger.error(`❌ Error al enviar job a cola: ${error.message}`);
      this.logger.error(`❌ Stack trace: ${error.stack}`);
      this.logger.error(`❌ Error completo: ${JSON.stringify(error, Object.getOwnPropertyNames(error))}`);

      // Limpiar archivos si falló el envío a cola
      await this.compensationService.cleanupFiles({
        audioFileKey,
        coverFileKey,
      });

      // Actualizar registro con error
      await this.uploadRepository.update(uploadRecord.id, {
        status: UploadStatus.FAILED,
        error: `Error al enviar job: ${error.message}`,
      });

      throw new BadRequestException(`Error al iniciar procesamiento: ${error.message}`);
    }
  }

  /**
   * Obtiene el estado de un upload
   */
  async getUploadStatus(uploadId: string, userId: string): Promise<SongUpload> {
    const upload = await this.uploadRepository.findOne({
      where: { uploadId, userId },
    });

    if (!upload) {
      throw new NotFoundException(`Upload no encontrado: ${uploadId}`);
    }

    return upload;
  }

  /**
   * Genera un ID único para el upload
   */
  private generateUploadId(): string {
    return `upload-${Date.now()}-${uuidv4().substring(0, 8)}`;
  }
}

