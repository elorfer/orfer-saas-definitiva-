import { Injectable, BadRequestException, Logger } from '@nestjs/common';
import { exec } from 'child_process';
import { promisify } from 'util';

const execAsync = promisify(exec);

/**
 * Servicio para extraer metadatos de archivos de audio
 * Usa music-metadata que funciona sin necesidad de ffmpeg instalado
 */
@Injectable()
export class AudioMetadataService {
  private readonly logger = new Logger(AudioMetadataService.name);
  private musicMetadataModule: any = null; // Caché del módulo music-metadata
  private readonly isDevelopment = process.env.NODE_ENV !== 'production';

  /**
   * Extrae metadatos de un archivo de audio
   * @param fileBuffer Buffer del archivo de audio
   * @param mimeType Tipo MIME del archivo
   * @returns Metadatos del audio incluyendo duración en segundos
   */
  async extractMetadata(
    fileBuffer: Buffer,
    mimeType: string,
  ): Promise<{
    duration: number; // en segundos
    bitrate?: number;
    codec?: string;
    sampleRate?: number;
    channels?: number;
    format?: string;
    title?: string;
    artist?: string;
    album?: string;
  }> {
    if (this.isDevelopment) {
      this.logger.log(`🔍 Extrayendo metadatos de audio (tipo: ${mimeType}, tamaño: ${(fileBuffer.length / 1024 / 1024).toFixed(2)} MB)`);
    }
    
    try {
      // Intentar usar music-metadata si está disponible
      // Si no está disponible, usar método alternativo
      const metadata = await this.extractWithMusicMetadata(fileBuffer, mimeType);
      if (this.isDevelopment) {
        this.logger.log(`✅ Metadatos extraídos con music-metadata: duración=${metadata.duration}s`);
      }
      return metadata;
    } catch (error) {
      if (this.isDevelopment) {
        this.logger.warn(`⚠️ No se pudo extraer metadatos con music-metadata: ${error.message}`);
      }
      
      // Fallback 1: intentar usar ffprobe si está disponible
      try {
        if (this.isDevelopment) {
          this.logger.log('🔄 Intentando extracción con ffprobe...');
        }
        const ffprobeMetadata = await this.extractWithFfprobe(fileBuffer, mimeType);
        if (ffprobeMetadata.duration > 0 && this.isDevelopment) {
          this.logger.log(`✅ Duración extraída (ffprobe): ${ffprobeMetadata.duration}s`);
        }
        if (ffprobeMetadata.duration > 0) {
          return ffprobeMetadata;
        }
      } catch (ffprobeError) {
        if (this.isDevelopment) {
          this.logger.warn(`⚠️ No se pudo extraer con ffprobe: ${ffprobeError.message}`);
        }
      }
      
      // Fallback 2: intentar extraer duración básica
      try {
        if (this.isDevelopment) {
          this.logger.log('🔄 Intentando extracción básica de metadatos...');
        }
        const basicMetadata = await this.extractBasicMetadata(fileBuffer, mimeType);
        if (basicMetadata.duration > 0 && this.isDevelopment) {
          this.logger.log(`✅ Duración extraída (método básico): ${basicMetadata.duration}s`);
        } else if (basicMetadata.duration === 0 && this.isDevelopment) {
          this.logger.warn('⚠️ No se pudo extraer duración con método básico');
        }
        return basicMetadata;
      } catch (fallbackError) {
        this.logger.error(`❌ Error al extraer metadatos básicos: ${fallbackError.message}`);
        if (this.isDevelopment) {
          this.logger.warn('⚠️ Usando valores por defecto (duración = 0)');
        }
        // Retornar valores por defecto si todo falla
        return {
          duration: 0,
          bitrate: 128000,
          codec: 'unknown',
          sampleRate: 44100,
          channels: 2,
          format: this.getFormatFromMimeType(mimeType),
        };
      }
    }
  }

  /**
   * Extrae metadatos usando music-metadata (requiere npm install music-metadata)
   */
  private async extractWithMusicMetadata(
    fileBuffer: Buffer,
    mimeType: string,
  ): Promise<any> {
    // Usar caché del módulo si ya está cargado
    let mm = this.musicMetadataModule;
    
    if (!mm) {
      // Cargar módulo solo la primera vez
      try {
        // Intentar require directo primero (debería funcionar desde /app)
        mm = require('music-metadata');
        if (this.isDevelopment) {
          this.logger.log('✅ music-metadata cargado exitosamente');
          this.logger.log(`   - CWD: ${process.cwd()}`);
          this.logger.log(`   - parseBuffer disponible: ${typeof mm.parseBuffer === 'function' ? 'SÍ' : 'NO'}`);
        }
        // Guardar en caché
        this.musicMetadataModule = mm;
      } catch (requireError: any) {
        // Si falla, intentar con resolución explícita
        try {
          const path = require('path');
          const cwd = process.cwd();
          const musicMetadataPath = require.resolve('music-metadata', { paths: [cwd] });
          if (this.isDevelopment) {
            this.logger.log(`✅ music-metadata resuelto desde: ${musicMetadataPath}`);
          }
          mm = require(musicMetadataPath);
          // Guardar en caché
          this.musicMetadataModule = mm;
        } catch (resolveError: any) {
          this.logger.error(`❌ Error al importar music-metadata`);
          this.logger.error(`   - Require error: ${requireError.message}`);
          this.logger.error(`   - Resolve error: ${resolveError.message}`);
          if (this.isDevelopment) {
            this.logger.error(`   - CWD: ${process.cwd()}`);
            this.logger.error(`   - __dirname: ${__dirname}`);
            if (requireError.stack) {
              this.logger.error(`   - Require stack: ${requireError.stack.split('\n').slice(0, 3).join('\n   ')}`);
            }
          }
          this.logger.warn('⚠️ music-metadata no está instalado. Ejecuta: npm install music-metadata');
          throw new Error('music-metadata no está instalado. Ejecuta: npm install music-metadata');
        }
      }
    }
    
    if (this.isDevelopment) {
      this.logger.log('✅ music-metadata disponible - usando extracción completa');
      this.logger.log(`   - Buffer size: ${(fileBuffer.length / 1024 / 1024).toFixed(2)} MB`);
      this.logger.log(`   - MIME type: ${mimeType}`);
      this.logger.log('🔄 Analizando archivo con music-metadata...');
    }

    let metadata;
    try {
      // music-metadata v11+ usa parseBuffer para buffers
      // La API correcta es: parseBuffer(buffer, options)
      if (typeof mm.parseBuffer === 'function') {
        if (this.isDevelopment) {
          this.logger.log('   - Usando parseBuffer API');
        }
        metadata = await mm.parseBuffer(fileBuffer, { mimeType });
        if (this.isDevelopment) {
          this.logger.log(`   - Parse completado exitosamente`);
        }
      } else if (mm.parse && typeof mm.parse === 'function') {
        if (this.isDevelopment) {
          this.logger.log('   - Usando parse API (fallback)');
        }
        metadata = await mm.parse(fileBuffer, { mimeType });
      } else {
        this.logger.error('❌ API de music-metadata no reconocida');
        this.logger.error(`   - Funciones disponibles: ${Object.keys(mm).filter(k => typeof mm[k] === 'function').join(', ')}`);
        throw new Error('API de music-metadata no reconocida');
      }
    } catch (parseError) {
      this.logger.error(`❌ Error al parsear con music-metadata: ${parseError.message}`);
      this.logger.error(`   - Tipo de error: ${parseError.constructor.name}`);
      if (this.isDevelopment && parseError.stack) {
        this.logger.error(`   - Stack: ${parseError.stack.split('\n').slice(0, 5).join('\n   ')}`);
      }
      throw parseError;
    }
    
    const duration = metadata.format?.duration 
      ? Math.round(metadata.format.duration) 
      : 0;

    const result = {
      duration,
      bitrate: metadata.format?.bitrate,
      codec: metadata.format?.codec,
      sampleRate: metadata.format?.sampleRate,
      channels: metadata.format?.numberOfChannels,
      format: metadata.format?.container || mimeType,
      title: metadata.common?.title,
      artist: metadata.common?.artist,
      album: metadata.common?.album,
    };

    if (this.isDevelopment) {
      this.logger.log(`📊 Metadatos completos: duración=${duration}s, codec=${result.codec}, bitrate=${result.bitrate}, sampleRate=${result.sampleRate}Hz, canales=${result.channels}`);
      if (result.title || result.artist) {
        this.logger.log(`🎵 ID3 Tags: "${result.title}" - ${result.artist}${result.album ? ` (${result.album})` : ''}`);
      }
    }

    return result;
  }

  /**
   * Extrae metadatos usando ffprobe (ffmpeg)
   */
  private async extractWithFfprobe(
    fileBuffer: Buffer,
    mimeType: string,
  ): Promise<any> {
    const fs = require('fs');
    const path = require('path');
    const os = require('os');

    // Crear archivo temporal
    const tempDir = os.tmpdir();
    const tempFileName = `temp_audio_${Date.now()}_${Math.random().toString(36).substring(7)}.${this.getFormatFromMimeType(mimeType)}`;
    const tempFilePath = path.join(tempDir, tempFileName);

    try {
      // Escribir buffer a archivo temporal
      fs.writeFileSync(tempFilePath, fileBuffer);

      // Ejecutar ffprobe para obtener duración
      const { stdout } = await execAsync(
        `ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "${tempFilePath}"`,
        { timeout: 10000 } // 10 segundos de timeout
      );

      const duration = parseFloat(stdout.trim());
      
      if (isNaN(duration) || duration <= 0) {
        throw new Error('Duración inválida de ffprobe');
      }

      // Obtener más información si es posible
      let bitrate = 128000;
      let codec = 'unknown';
      let sampleRate = 44100;
      let channels = 2;

      try {
        const { stdout: formatInfo } = await execAsync(
          `ffprobe -v error -select_streams a:0 -show_entries stream=bit_rate,codec_name,sample_rate,channels -of default=noprint_wrappers=1 "${tempFilePath}"`,
          { timeout: 5000 }
        );

        const lines = formatInfo.trim().split('\n');
        for (const line of lines) {
          if (line.startsWith('bit_rate=')) {
            bitrate = parseInt(line.split('=')[1]) || bitrate;
          } else if (line.startsWith('codec_name=')) {
            codec = line.split('=')[1] || codec;
          } else if (line.startsWith('sample_rate=')) {
            sampleRate = parseInt(line.split('=')[1]) || sampleRate;
          } else if (line.startsWith('channels=')) {
            channels = parseInt(line.split('=')[1]) || channels;
          }
        }
      } catch (infoError) {
        // Ignorar errores al obtener información adicional
        if (this.isDevelopment) {
          this.logger.warn(`⚠️ No se pudo obtener información adicional de ffprobe: ${infoError.message}`);
        }
      }

      return {
        duration: Math.round(duration),
        bitrate,
        codec,
        sampleRate,
        channels,
        format: this.getFormatFromMimeType(mimeType),
      };
    } catch (error) {
      if (this.isDevelopment) {
        this.logger.warn(`⚠️ Error al usar ffprobe: ${error.message}`);
      }
      throw error;
    } finally {
      // Limpiar archivo temporal
      try {
        if (fs.existsSync(tempFilePath)) {
          fs.unlinkSync(tempFilePath);
        }
      } catch (cleanupError) {
        // Ignorar errores de limpieza
        if (this.isDevelopment) {
          this.logger.warn(`⚠️ Error al limpiar archivo temporal: ${cleanupError.message}`);
        }
      }
    }
  }

  /**
   * Extrae metadatos básicos sin bibliotecas externas
   * Método simple que funciona para algunos formatos
   */
  private async extractBasicMetadata(
    fileBuffer: Buffer,
    mimeType: string,
  ): Promise<any> {
    // Para MP3, intentar leer duración desde headers ID3
    if (mimeType === 'audio/mpeg' || mimeType === 'audio/mp3') {
      const duration = this.extractMP3Duration(fileBuffer);
      if (duration > 0) {
        return {
          duration,
          format: 'mp3',
          codec: 'mp3',
        };
      }
    }

    // Si no se puede extraer, retornar 0
    return {
      duration: 0,
      format: this.getFormatFromMimeType(mimeType),
    };
  }

  /**
   * Intenta extraer duración de MP3 desde el buffer
   * Método básico que lee frames MP3
   */
  private extractMP3Duration(buffer: Buffer): number {
    try {
      if (this.isDevelopment) {
        this.logger.log('🔄 Intentando extraer duración MP3 (método básico)...');
      }
      
      // Buscar frame sync (0xFF 0xFB o 0xFF 0xFA)
      let offset = 0;
      let frameCount = 0;
      let totalFrameSize = 0;
      let foundValidFrame = false;

      // Buscar en los primeros 100KB del archivo para encontrar frames válidos
      const searchLimit = Math.min(buffer.length, 100000);
      
      while (offset < searchLimit - 4) {
        // Buscar sync word (0xFF seguido de 111xxxxx)
        if (buffer[offset] === 0xFF && (buffer[offset + 1] & 0xE0) === 0xE0) {
          // Leer header del frame
          const version = (buffer[offset + 1] & 0x18) >> 3;
          const layer = (buffer[offset + 1] & 0x06) >> 1;
          const bitrateIndex = (buffer[offset + 2] & 0xF0) >> 4;
          const sampleRateIndex = (buffer[offset + 2] & 0x0C) >> 2;
          const padding = (buffer[offset + 2] & 0x02) >> 1;

          // Calcular tamaño del frame
          const bitrates = [
            [0, 32, 64, 96, 128, 160, 192, 224, 256, 288, 320, 352, 384, 416, 448],
            [0, 32, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 384],
            [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320],
          ];

          const sampleRates = [
            [44100, 48000, 32000],
            [22050, 24000, 16000],
            [11025, 12000, 8000],
          ];

          // Validar que sea un frame MP3 válido (version !== 1 significa MPEG-1, layer === 1 significa Layer III)
          if (version !== 1 && layer === 1 && bitrateIndex > 0 && bitrateIndex < 15 && sampleRateIndex < 3) {
            const bitrate = bitrates[version][bitrateIndex] * 1000;
            const sampleRate = sampleRates[version][sampleRateIndex];
            const frameSize = Math.floor((144 * bitrate) / sampleRate) + padding;

            if (frameSize > 0 && frameSize < 2000) { // Validar tamaño razonable
              totalFrameSize += frameSize;
              frameCount++;
              offset += frameSize;
              foundValidFrame = true;

              // Si tenemos suficientes frames, calcular duración
              if (frameCount >= 5) {
                const avgFrameSize = totalFrameSize / frameCount;
                const estimatedFrames = buffer.length / avgFrameSize;
                const duration = estimatedFrames * 0.026; // 26ms por frame (1152 samples / 44100 Hz)
                const roundedDuration = Math.round(duration);
                
                if (roundedDuration > 0 && roundedDuration < 3600) { // Validar duración razonable (menos de 1 hora)
                  if (this.isDevelopment) {
                    this.logger.log(`✅ Duración MP3 extraída (método básico): ${roundedDuration}s (${Math.floor(roundedDuration / 60)}:${(roundedDuration % 60).toString().padStart(2, '0')})`);
                  }
                  return roundedDuration;
                }
              }
            } else {
              offset++;
            }
          } else {
            offset++;
          }
        } else {
          offset++;
        }
      }
      
      if (!foundValidFrame) {
        this.logger.warn('⚠️ No se encontraron frames MP3 válidos en el archivo');
      } else {
        this.logger.warn('⚠️ Se encontraron frames pero no se pudo calcular duración confiable');
      }
    } catch (error) {
      this.logger.warn(`⚠️ Error al extraer duración MP3: ${error.message}`);
    }

    return 0;
  }

  /**
   * Obtiene el formato del archivo desde el MIME type
   */
  private getFormatFromMimeType(mimeType: string): string {
    const mimeToFormat: Record<string, string> = {
      'audio/mpeg': 'mp3',
      'audio/mp3': 'mp3',
      'audio/wav': 'wav',
      'audio/x-wav': 'wav',
      'audio/m4a': 'm4a',
      'audio/x-m4a': 'm4a',
      'audio/flac': 'flac',
      'audio/x-flac': 'flac',
    };

    return mimeToFormat[mimeType] || 'unknown';
  }
}

