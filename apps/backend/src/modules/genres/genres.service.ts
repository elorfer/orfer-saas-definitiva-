import { Injectable, NotFoundException, BadRequestException, ConflictException, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';

import { Genre } from '../../common/entities/genre.entity';
import { CreateGenreDto } from './dto/create-genre.dto';
import { UpdateGenreDto } from './dto/update-genre.dto';

/**
 * Servicio para gestionar géneros musicales
 * Proporciona operaciones CRUD completas para géneros
 */
@Injectable()
export class GenresService {
  private readonly logger = new Logger(GenresService.name);

  constructor(
    @InjectRepository(Genre)
    private readonly genreRepository: Repository<Genre>,
  ) {}

  /**
   * Obtiene todos los géneros con paginación
   * @param page Número de página (por defecto: 1)
   * @param limit Límite de resultados por página (por defecto: 50)
   * @returns Lista paginada de géneros
   */
  async findAll(page: number = 1, limit: number = 50): Promise<{ genres: Genre[]; total: number; page: number; limit: number; totalPages: number }> {
    const [genres, total] = await this.genreRepository.findAndCount({
      order: { name: 'ASC' },
      skip: (page - 1) * limit,
      take: limit,
    });

    return {
      genres,
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    };
  }

  /**
   * Obtiene todos los géneros sin paginación (útil para selectores)
   * @returns Lista completa de géneros
   */
  async findAllWithoutPagination(): Promise<Genre[]> {
    return this.genreRepository.find({
      order: { name: 'ASC' },
    });
  }

  /**
   * Obtiene un género por su ID
   * @param id ID del género
   * @returns Género encontrado
   * @throws NotFoundException si el género no existe
   */
  async findOne(id: string): Promise<Genre> {
    const genre = await this.genreRepository.findOne({
      where: { id },
      relations: ['songs', 'albums'],
    });

    if (!genre) {
      throw new NotFoundException(`Género con ID ${id} no encontrado`);
    }

    return genre;
  }

  /**
   * Obtiene un género por su nombre
   * @param name Nombre del género
   * @returns Género encontrado o null
   */
  async findByName(name: string): Promise<Genre | null> {
    return this.genreRepository.findOne({
      where: { name },
    });
  }

  /**
   * Crea un nuevo género musical
   * @param createGenreDto Datos del género a crear
   * @returns Género creado
   * @throws ConflictException si el género ya existe
   */
  async create(createGenreDto: CreateGenreDto): Promise<Genre> {
    // Verificar si el género ya existe (el nombre debe ser único)
    const existingGenre = await this.findByName(createGenreDto.name);
    
    if (existingGenre) {
      throw new ConflictException(`El género "${createGenreDto.name}" ya existe`);
    }

    try {
      const genre = this.genreRepository.create({
        name: createGenreDto.name.trim(),
        description: createGenreDto.description?.trim(),
        colorHex: createGenreDto.colorHex?.trim(),
      });

      const savedGenre = await this.genreRepository.save(genre);
      this.logger.log(`Género creado exitosamente: ${savedGenre.name} (ID: ${savedGenre.id})`);
      
      return savedGenre;
    } catch (error) {
      this.logger.error(`Error al crear género: ${error.message}`, error.stack);
      
      // Si es un error de constraint único de PostgreSQL
      if (error.code === '23505') {
        throw new ConflictException(`El género "${createGenreDto.name}" ya existe`);
      }
      
      throw new BadRequestException(`Error al crear género: ${error.message}`);
    }
  }

  /**
   * Actualiza un género existente
   * @param id ID del género a actualizar
   * @param updateGenreDto Datos a actualizar
   * @returns Género actualizado
   * @throws NotFoundException si el género no existe
   * @throws ConflictException si el nuevo nombre ya existe
   */
  async update(id: string, updateGenreDto: UpdateGenreDto): Promise<Genre> {
    const genre = await this.findOne(id);

    // Si se está actualizando el nombre, verificar que no exista otro género con ese nombre
    if (updateGenreDto.name && updateGenreDto.name.trim() !== genre.name) {
      const existingGenre = await this.findByName(updateGenreDto.name.trim());
      
      if (existingGenre && existingGenre.id !== id) {
        throw new ConflictException(`El género "${updateGenreDto.name}" ya existe`);
      }
    }

    // Actualizar campos proporcionados
    if (updateGenreDto.name !== undefined) {
      genre.name = updateGenreDto.name.trim();
    }
    if (updateGenreDto.description !== undefined) {
      genre.description = updateGenreDto.description?.trim() || null;
    }
    if (updateGenreDto.colorHex !== undefined) {
      genre.colorHex = updateGenreDto.colorHex?.trim() || null;
    }

    try {
      const updatedGenre = await this.genreRepository.save(genre);
      this.logger.log(`Género actualizado exitosamente: ${updatedGenre.name} (ID: ${updatedGenre.id})`);
      
      return updatedGenre;
    } catch (error) {
      this.logger.error(`Error al actualizar género: ${error.message}`, error.stack);
      
      // Si es un error de constraint único de PostgreSQL
      if (error.code === '23505') {
        throw new ConflictException(`El género "${updateGenreDto.name}" ya existe`);
      }
      
      throw new BadRequestException(`Error al actualizar género: ${error.message}`);
    }
  }

  /**
   * Elimina un género
   * @param id ID del género a eliminar
   * @returns Mensaje de confirmación
   * @throws NotFoundException si el género no existe
   * @throws BadRequestException si el género está en uso
   */
  async remove(id: string): Promise<{ message: string; genre: Genre }> {
    const genre = await this.findOne(id);

    // Verificar si el género está siendo usado por canciones o álbumes
    const songsCount = genre.songs?.length || 0;
    const albumsCount = genre.albums?.length || 0;

    if (songsCount > 0 || albumsCount > 0) {
      throw new BadRequestException(
        `No se puede eliminar el género "${genre.name}" porque está siendo usado por ${songsCount} canción(es) y ${albumsCount} álbum(es)`
      );
    }

    try {
      await this.genreRepository.remove(genre);
      this.logger.log(`Género eliminado exitosamente: ${genre.name} (ID: ${id})`);
      
      return {
        message: `Género "${genre.name}" eliminado exitosamente`,
        genre,
      };
    } catch (error) {
      this.logger.error(`Error al eliminar género: ${error.message}`, error.stack);
      throw new BadRequestException(`Error al eliminar género: ${error.message}`);
    }
  }

  /**
   * Busca géneros por nombre (búsqueda parcial)
   * @param query Término de búsqueda
   * @param limit Límite de resultados
   * @returns Lista de géneros que coinciden con la búsqueda
   */
  async search(query: string, limit: number = 20): Promise<Genre[]> {
    return this.genreRepository
      .createQueryBuilder('genre')
      .where('genre.name ILIKE :query', { query: `%${query}%` })
      .orderBy('genre.name', 'ASC')
      .limit(limit)
      .getMany();
  }
}






