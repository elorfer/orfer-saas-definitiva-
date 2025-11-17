import {
  Controller,
  Get,
  Post,
  Param,
  Delete,
  Patch,
  Body,
  UseGuards,
  Query,
  ParseIntPipe,
  UseInterceptors,
  UploadedFile,
  UploadedFiles,
  BadRequestException,
  UseFilters,
  UsePipes,
  Req,
} from '@nestjs/common';
import { Request } from 'express';
import { FileFieldsInterceptor } from '@nestjs/platform-express';
import { MulterError } from 'multer';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth, ApiQuery, ApiConsumes, ApiBody, ApiParam } from '@nestjs/swagger';

import { SongsService } from './songs.service';
import { UploadOrchestratorService } from './upload-orchestrator.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { User } from '../../common/entities/user.entity';
import { MulterExceptionInterceptor } from '../../common/interceptors/multer-exception.interceptor';
import { SkipValidationPipe } from '../../common/pipes/skip-validation.pipe';
import { FileValidationService } from '../../common/services/file-validation.service';
import { Logger, HttpCode, HttpStatus } from '@nestjs/common';

@ApiTags('songs')
@Controller('songs')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class SongsController {
  private readonly logger = new Logger(SongsController.name);

  constructor(
    private readonly songsService: SongsService,
    private readonly uploadOrchestratorService: UploadOrchestratorService,
    private readonly fileValidationService: FileValidationService,
  ) {}

  @Get()
  @ApiOperation({ summary: 'Obtener todas las canciones' })
  @ApiQuery({ name: 'page', required: false, type: Number })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiQuery({ name: 'all', required: false, type: Boolean, description: 'Incluir todas las canciones (no solo publicadas)' })
  @ApiResponse({ status: 200, description: 'Lista de canciones obtenida exitosamente' })
  async findAll(
    @Query('page', new ParseIntPipe({ optional: true })) page: number = 1,
    @Query('limit', new ParseIntPipe({ optional: true })) limit: number = 10,
    @Query('all') all?: string,
  ) {
    const includeAllStatuses = all === 'true' || all === '1';
    return this.songsService.findAll(page, limit, includeAllStatuses);
  }

  @Get('top')
  @ApiOperation({ summary: 'Obtener canciones más populares' })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiResponse({ status: 200, description: 'Lista de canciones top' })
  async getTopSongs(
    @Query('limit', new ParseIntPipe({ optional: true })) limit: number = 10,
  ) {
    return this.songsService.getTopSongs(limit);
  }

  @Get('search')
  @ApiOperation({ summary: 'Buscar canciones' })
  @ApiQuery({ name: 'q', required: true, type: String, description: 'Término de búsqueda' })
  @ApiQuery({ name: 'page', required: false, type: Number })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiResponse({ status: 200, description: 'Resultados de búsqueda' })
  async searchSongs(
    @Query('q') query: string,
    @Query('page', new ParseIntPipe({ optional: true })) page: number = 1,
    @Query('limit', new ParseIntPipe({ optional: true })) limit: number = 10,
  ) {
    return this.songsService.searchSongs(query, page, limit);
  }

  @Get('artist/:artistId')
  @ApiOperation({ summary: 'Obtener canciones de un artista' })
  @ApiQuery({ name: 'page', required: false, type: Number })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiResponse({ status: 200, description: 'Canciones del artista' })
  async findByArtist(
    @Param('artistId') artistId: string,
    @Query('page', new ParseIntPipe({ optional: true })) page: number = 1,
    @Query('limit', new ParseIntPipe({ optional: true })) limit: number = 10,
  ) {
    return this.songsService.findByArtist(artistId, page, limit);
  }

  @Get('genre/:genreId')
  @ApiOperation({ summary: 'Obtener canciones por género' })
  @ApiQuery({ name: 'page', required: false, type: Number })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiResponse({ status: 200, description: 'Canciones del género' })
  async getSongsByGenre(
    @Param('genreId') genreId: string,
    @Query('page', new ParseIntPipe({ optional: true })) page: number = 1,
    @Query('limit', new ParseIntPipe({ optional: true })) limit: number = 10,
  ) {
    return this.songsService.getSongsByGenre(genreId, page, limit);
  }

  @Get('upload/:uploadId/status')
  @ApiOperation({ summary: 'Consultar estado de un upload' })
  @ApiResponse({ status: 200, description: 'Estado del upload' })
  @ApiResponse({ status: 404, description: 'Upload no encontrado' })
  async getUploadStatus(
    @Param('uploadId') uploadId: string,
    @CurrentUser() user: User,
  ) {
    return this.uploadOrchestratorService.getUploadStatus(uploadId, user.id);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Obtener canción por ID' })
  @ApiResponse({ status: 200, description: 'Canción encontrada' })
  @ApiResponse({ status: 404, description: 'Canción no encontrada' })
  async findOne(@Param('id') id: string) {
    return this.songsService.findOne(id);
  }

  // IMPORTANTE: Las rutas específicas deben ir ANTES de las rutas con parámetros dinámicos
  @Post('upload')
  @HttpCode(HttpStatus.ACCEPTED)
  @UsePipes(new SkipValidationPipe())
  @UseInterceptors(
    MulterExceptionInterceptor,
    FileFieldsInterceptor([
      { name: 'audio', maxCount: 1 },
      { name: 'cover', maxCount: 1 },
    ], {
      limits: {
        fileSize: 100 * 1024 * 1024, // 100MB (límite global, validación específica en servicio)
      },
      fileFilter: (req, file, callback) => {
        // Validación básica en el interceptor (validación completa en el servicio)
        const allowedAudioTypes = [
          'audio/mpeg', 'audio/mp3', 'audio/wav', 'audio/x-wav',
          'audio/m4a', 'audio/x-m4a', 'audio/flac', 'audio/x-flac',
        ];
        const allowedImageTypes = [
          'image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/gif',
        ];
        
        if (file.fieldname === 'audio') {
          if (allowedAudioTypes.includes(file.mimetype)) {
            callback(null, true);
          } else {
            callback(new Error(`Tipo de archivo de audio no permitido: ${file.mimetype}`), false);
          }
        } else if (file.fieldname === 'cover') {
          if (allowedImageTypes.includes(file.mimetype)) {
            callback(null, true);
          } else {
            callback(new Error(`Tipo de archivo de imagen no permitido: ${file.mimetype}`), false);
          }
        } else {
          callback(null, true);
        }
      },
    })
  )
  @ApiOperation({ 
    summary: 'Subir canción (procesamiento asíncrono)',
    description: 'Inicia el proceso de subida de canción. Responde 202 Accepted y procesa en background. Usa el endpoint GET /songs/upload/:uploadId para consultar el estado.',
  })
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        uploadId: { type: 'string', description: 'ID opcional para idempotencia (si no se proporciona, se genera automáticamente)' },
        audio: { type: 'string', format: 'binary' },
        cover: { type: 'string', format: 'binary' },
        title: { type: 'string' },
        artistId: { type: 'string' },
        albumId: { type: 'string' },
        genreId: { type: 'string' },
        status: { type: 'string', enum: ['draft', 'pending', 'published', 'rejected'] },
        duration: { type: 'number' },
      },
      required: ['audio', 'title', 'artistId'],
    },
  })
  @ApiResponse({
    status: 202,
    description: 'Upload iniciado, procesando en segundo plano',
    schema: {
      type: 'object',
      properties: {
        uploadId: { type: 'string' },
        status: { type: 'string', enum: ['pending', 'processing', 'completed', 'failed'] },
        jobId: { type: 'string' },
        message: { type: 'string' },
        checkStatusUrl: { type: 'string' },
      },
    },
  })
  @ApiResponse({ status: 400, description: 'Error en el archivo o formato no válido' })
  async uploadSong(
    @UploadedFiles() files: { audio?: Express.Multer.File[]; cover?: Express.Multer.File[] },
    @Req() req: Request,
    @CurrentUser() user: User,
  ) {
    this.logger.log('═══════════════════════════════════════════════════════════');
    this.logger.log('🚀 NUEVA PETICIÓN DE SUBIDA DE CANCIÓN (ASÍNCRONA)');
    this.logger.log(`👤 Usuario: ${user.email} (${user.id})`);
    this.logger.log('═══════════════════════════════════════════════════════════');

    if (!files || !files.audio || files.audio.length === 0) {
      throw new BadRequestException('Debe proporcionar un archivo de audio en el campo "audio"');
    }

    const audioFile = files.audio[0];
    const coverFile = files.cover && files.cover.length > 0 ? files.cover[0] : undefined;

    this.logger.log(`📦 Archivos recibidos:`);
    this.logger.log(`   - Audio: ${audioFile.originalname} (${(audioFile.size / 1024 / 1024).toFixed(2)} MB, ${audioFile.mimetype})`);
    if (coverFile) {
      this.logger.log(`   - Portada: ${coverFile.originalname} (${(coverFile.size / 1024 / 1024).toFixed(2)} MB, ${coverFile.mimetype})`);
    }

    // Validación centralizada usando el servicio
    this.logger.log('🔍 Validando archivos...');
    this.fileValidationService.validateAudioFile(audioFile, 'audio');
    if (coverFile) {
      this.fileValidationService.validateImageFile(coverFile, 'cover');
    }
    this.logger.log('✅ Archivos validados correctamente');

    // Extraer campos de texto del body (FormData envía campos de texto en req.body)
    const title = req.body?.title;
    const artistId = req.body?.artistId;
    const uploadId = req.body?.uploadId; // ID opcional para idempotencia
    
    this.logger.log(`📝 Datos de la canción:`);
    this.logger.log(`   - Título: ${title}`);
    this.logger.log(`   - Artista ID: ${artistId}`);
    if (uploadId) {
      this.logger.log(`   - Upload ID (cliente): ${uploadId}`);
    }

    if (!title || !title.trim()) {
      throw new BadRequestException('El campo "title" es requerido');
    }

    if (!artistId || !artistId.trim()) {
      throw new BadRequestException('El campo "artistId" es requerido');
    }

    // Iniciar proceso asíncrono usando el orquestador
    const result = await this.uploadOrchestratorService.initiateUpload({
      uploadId,
      audioFile,
      coverFile,
      title: title.trim(),
      artistId: artistId.trim(),
      albumId: req.body?.albumId?.trim(),
      genreId: req.body?.genreId?.trim(),
      status: req.body?.status?.trim() as 'draft' | 'pending' | 'published' | 'rejected' | undefined,
      duration: req.body?.duration ? Number.parseFloat(req.body.duration) : undefined,
      userId: user.id,
    });

    this.logger.log('═══════════════════════════════════════════════════════════');
    this.logger.log('✅ SUBIDA INICIADA - PROCESANDO EN BACKGROUND');
    this.logger.log('═══════════════════════════════════════════════════════════');

    return {
      ...result,
      checkStatusUrl: `/api/v1/songs/upload/${result.uploadId}/status`,
    };
  }

  @Post()
  @ApiOperation({ summary: 'Crear nueva canción' })
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        title: { type: 'string' },
        fileUrl: { type: 'string' },
        coverImageUrl: { type: 'string' },
        artistId: { type: 'string' },
        albumId: { type: 'string' },
        genreId: { type: 'string' },
        status: { type: 'string', enum: ['draft', 'pending', 'published', 'rejected'], default: 'pending' },
        duration: { type: 'number' },
      },
      required: ['title', 'fileUrl', 'artistId'],
    },
  })
  @ApiResponse({ status: 201, description: 'Canción creada exitosamente' })
  @ApiResponse({ status: 400, description: 'Datos inválidos' })
  async createSong(@Body() createSongDto: any) {
    return this.songsService.create(createSongDto);
  }

  @Post(':id/stream')
  @ApiOperation({ summary: 'Registrar reproducción de canción' })
  @ApiResponse({ status: 200, description: 'Reproducción registrada' })
  async streamSong(
    @Param('id') id: string,
    @CurrentUser() user: User,
  ) {
    await this.songsService.incrementStreams(id);
    return { message: 'Reproducción registrada' };
  }

  @Post(':id/like')
  @ApiOperation({ summary: 'Dar like a una canción' })
  @ApiResponse({ status: 200, description: 'Like registrado' })
  async likeSong(
    @Param('id') id: string,
    @CurrentUser() user: User,
  ) {
    await this.songsService.likeSong(id, user.id);
    return { message: 'Like registrado' };
  }

  @Post(':id/unlike')
  @ApiOperation({ summary: 'Quitar like de una canción' })
  @ApiResponse({ status: 200, description: 'Like removido' })
  async unlikeSong(
    @Param('id') id: string,
    @CurrentUser() user: User,
  ) {
    await this.songsService.unlikeSong(id, user.id);
    return { message: 'Like removido' };
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Eliminar canción' })
  @ApiResponse({ status: 200, description: 'Canción eliminada exitosamente' })
  @ApiResponse({ status: 404, description: 'Canción no encontrada' })
  async remove(@Param('id') id: string) {
    await this.songsService.remove(id);
    return { message: 'Canción eliminada exitosamente' };
  }

  @Post(':id/update-duration')
  @ApiOperation({ summary: 'Actualizar duración de una canción desde su archivo de audio' })
  @ApiResponse({ status: 200, description: 'Duración actualizada exitosamente' })
  @ApiResponse({ status: 404, description: 'Canción no encontrada' })
  async updateDuration(@Param('id') id: string) {
    return this.songsService.updateDurationFromFile(id);
  }

  @Post('update-all-durations')
  @ApiOperation({ summary: 'Actualizar duraciones de todas las canciones con duración = 0' })
  @ApiResponse({ 
    status: 200, 
    description: 'Actualización completada',
    schema: {
      type: 'object',
      properties: {
        updated: { type: 'number' },
        failed: { type: 'number' },
        errors: { type: 'array', items: { type: 'string' } },
      },
    },
  })
  async updateAllDurations() {
    return this.songsService.updateAllDurations();
  }

  @Post(':id/feature')
  @ApiOperation({ summary: 'Marcar canción como destacada' })
  @ApiParam({ name: 'id', description: 'ID de la canción' })
  @ApiResponse({ status: 200, description: 'Canción marcada como destacada exitosamente' })
  @ApiResponse({ status: 404, description: 'Canción no encontrada' })
  async featureSong(@Param('id') id: string) {
    const song = await this.songsService.toggleFeatured(id, true);
    return { message: 'Canción marcada como destacada', song };
  }

  @Delete(':id/feature')
  @ApiOperation({ summary: 'Desmarcar canción como destacada' })
  @ApiParam({ name: 'id', description: 'ID de la canción' })
  @ApiResponse({ status: 200, description: 'Canción desmarcada como destacada exitosamente' })
  @ApiResponse({ status: 404, description: 'Canción no encontrada' })
  async unfeatureSong(@Param('id') id: string) {
    const song = await this.songsService.toggleFeatured(id, false);
    return { message: 'Canción desmarcada como destacada', song };
  }

  @Patch(':id/feature')
  @ApiOperation({ summary: 'Alternar estado destacado de una canción' })
  @ApiParam({ name: 'id', description: 'ID de la canción' })
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        featured: { type: 'boolean', description: 'Estado destacado' },
      },
      required: ['featured'],
    },
  })
  @ApiResponse({ status: 200, description: 'Estado destacado actualizado exitosamente' })
  @ApiResponse({ status: 404, description: 'Canción no encontrada' })
  async toggleFeatured(
    @Param('id') id: string,
    @Body('featured') featured: boolean,
  ) {
    const song = await this.songsService.toggleFeatured(id, featured);
    return { 
      message: featured ? 'Canción marcada como destacada' : 'Canción desmarcada como destacada',
      song,
    };
  }
}









