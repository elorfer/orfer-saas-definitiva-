import {
  Controller,
  Post,
  UseGuards,
  UseInterceptors,
  UploadedFile,
  BadRequestException,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth, ApiConsumes } from '@nestjs/swagger';

import { CoversService } from './covers.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { User } from '../../common/entities/user.entity';

@ApiTags('covers')
@Controller('covers')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class CoversController {
  constructor(private readonly coversService: CoversService) {}

  @Post('upload')
  @UseInterceptors(
    FileInterceptor('file', {
      limits: {
        fileSize: 10 * 1024 * 1024, // 10MB para imágenes
      },
      fileFilter: (req, file, callback) => {
        // Validar solo imágenes permitidas
        const allowedMimeTypes = [
          'image/jpeg',
          'image/jpg',
          'image/png',
          'image/webp',
        ];

        if (allowedMimeTypes.includes(file.mimetype)) {
          callback(null, true);
        } else {
          callback(
            new Error('Tipo de archivo no permitido. Solo se permiten: .jpg, .jpeg, .png, .webp'),
            false,
          );
        }
      },
    })
  )
  @ApiOperation({ summary: 'Subir imagen de portada de canción' })
  @ApiConsumes('multipart/form-data')
  @ApiResponse({
    status: 201,
    description: 'Portada subida exitosamente',
    schema: {
      type: 'object',
      properties: {
        url: { type: 'string', example: 'http://localhost:3000/uploads/covers/uuid-nombre.png' },
        fileName: { type: 'string', example: 'uuid-nombre.png' },
      },
    },
  })
  @ApiResponse({ status: 400, description: 'Error en el archivo o formato no válido' })
  async uploadCover(
    @UploadedFile() file: Express.Multer.File,
    @CurrentUser() user: User,
  ) {
    if (!file) {
      throw new BadRequestException('No se proporcionó archivo');
    }

    return this.coversService.uploadCover(file, user.id);
  }
}





