import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AffinityService } from './affinity.service';
import { UserAffinity } from '../../common/entities/user-affinity.entity';
import { Song } from '../../common/entities/song.entity';

@Module({
    imports: [
        TypeOrmModule.forFeature([UserAffinity, Song]),
    ],
    providers: [AffinityService],
    exports: [AffinityService], // Exportamos para que StreamsModule lo use
})
export class AffinityModule { }
