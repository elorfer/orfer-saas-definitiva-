import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Param,
  Body,
  Query,
  UseGuards,
  ParseIntPipe,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
  ApiQuery,
  ApiParam,
  ApiBody,
} from '@nestjs/swagger';

import { GenresService } from './genres.service';
import { CreateGenreDto } from './dto/create-genre.dto';
import { UpdateGenreDto } from './dto/update-genre.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { UserRole } from '../../common/entities/user.entity';

/**
 * Controlador para gestionar géneros musicales
 * Solo administradores pueden crear, actualizar y eliminar géneros
 * Todos los usuarios autenticados pueden consultar géneros
 */
@ApiTags('genres')
@Controller('genres')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class GenresController {
  constructor(private readonly genresService: GenresService) {}

  @Get()
  @ApiOperation({ summary: 'Obtener todos los géneros musicales' })
  @ApiQuery({ name: 'page', required: false, type: Number, description: 'Número de página' })
  @ApiQuery({ name: 'limit', required: false, type: Number, description: 'Límite de resultados por página' })
  @ApiQuery({ name: 'all', required: false, type: Boolean, description: 'Obtener todos los géneros sin paginación' })
  @ApiResponse({ status: 200, description: 'Lista de géneros obtenida exitosamente' })
  async findAll(
    @Query('page', new ParseIntPipe({ optional: true })) page: number = 1,
    @Query('limit', new ParseIntPipe({ optional: true })) limit: number = 50,
    @Query('all') all?: string,
  ) {
    // Si se solicita todos sin paginación
    if (all === 'true' || all === '1') {
      const genres = await this.genresService.findAllWithoutPagination();
      return { genres, total: genres.length };
    }

    return this.genresService.findAll(page, limit);
  }

  @Get('search')
  @ApiOperation({ summary: 'Buscar géneros por nombre' })
  @ApiQuery({ name: 'q', required: true, type: String, description: 'Término de búsqueda' })
  @ApiQuery({ name: 'limit', required: false, type: Number, description: 'Límite de resultados' })
  @ApiResponse({ status: 200, description: 'Resultados de búsqueda' })
  async search(
    @Query('q') query: string,
    @Query('limit', new ParseIntPipe({ optional: true })) limit: number = 20,
  ) {
    if (!query || query.trim().length === 0) {
      return { genres: [] };
    }
    const genres = await this.genresService.search(query.trim(), limit);
    return { genres, total: genres.length };
  }

  @Get(':id')
  @ApiOperation({ summary: 'Obtener un género por ID' })
  @ApiParam({ name: 'id', description: 'ID del género' })
  @ApiResponse({ status: 200, description: 'Género encontrado' })
  @ApiResponse({ status: 404, description: 'Género no encontrado' })
  async findOne(@Param('id') id: string) {
    return this.genresService.findOne(id);
  }

  @Post()
  @Roles(UserRole.ADMIN)
  @UseGuards(RolesGuard)
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Crear un nuevo género musical (Solo administradores)' })
  @ApiBody({ type: CreateGenreDto })
  @ApiResponse({ status: 201, description: 'Género creado exitosamente' })
  @ApiResponse({ status: 400, description: 'Datos inválidos' })
  @ApiResponse({ status: 409, description: 'El género ya existe' })
  @ApiResponse({ status: 403, description: 'No tienes permisos para crear géneros' })
  async create(@Body() createGenreDto: CreateGenreDto) {
    return this.genresService.create(createGenreDto);
  }

  @Patch(':id')
  @Roles(UserRole.ADMIN)
  @UseGuards(RolesGuard)
  @ApiOperation({ summary: 'Actualizar un género musical (Solo administradores)' })
  @ApiParam({ name: 'id', description: 'ID del género a actualizar' })
  @ApiBody({ type: UpdateGenreDto })
  @ApiResponse({ status: 200, description: 'Género actualizado exitosamente' })
  @ApiResponse({ status: 404, description: 'Género no encontrado' })
  @ApiResponse({ status: 409, description: 'El nombre del género ya existe' })
  @ApiResponse({ status: 403, description: 'No tienes permisos para actualizar géneros' })
  async update(
    @Param('id') id: string,
    @Body() updateGenreDto: UpdateGenreDto,
  ) {
    return this.genresService.update(id, updateGenreDto);
  }

  @Delete(':id')
  @Roles(UserRole.ADMIN)
  @UseGuards(RolesGuard)
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Eliminar un género musical (Solo administradores)' })
  @ApiParam({ name: 'id', description: 'ID del género a eliminar' })
  @ApiResponse({ status: 200, description: 'Género eliminado exitosamente' })
  @ApiResponse({ status: 404, description: 'Género no encontrado' })
  @ApiResponse({ status: 400, description: 'El género está en uso y no puede ser eliminado' })
  @ApiResponse({ status: 403, description: 'No tienes permisos para eliminar géneros' })
  async remove(@Param('id') id: string) {
    return this.genresService.remove(id);
  }
}





