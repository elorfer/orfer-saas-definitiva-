import { Module } from '@nestjs/common';
import { ScheduleModule } from '@nestjs/schedule';
import { CleanupService } from './cleanup.service';
import { UploadModule } from '../upload/upload.module';
import { ArtistsModule } from '../artists/artists.module';
// Importaremos más módulos (Songs, Users) según necesitemos verificar referencias

@Module({
    imports: [
        ScheduleModule.forRoot(),
        UploadModule, // Para acceder a S3Service
        ArtistsModule, // Para revisar artistas
    ],
    providers: [CleanupService],
})
export class CleanupModule { }
