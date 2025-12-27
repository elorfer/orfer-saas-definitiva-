
import { NestFactory } from '@nestjs/core';
import { AppModule } from '../src/app.module';
import { AdsService } from '../src/modules/ads/ads.service';
import { AdStatus } from '../src/common/entities/audio-ad.entity';
import { Logger } from '@nestjs/common';

async function bootstrap() {
    const app = await NestFactory.createApplicationContext(AppModule);
    const adsService = app.get(AdsService);
    const logger = new Logger('CheckAdsScript');

    logger.log('📢 Checking Active Ads...');

    try {
        const activeAds = await adsService.findActive();
        logger.log(`✅ Found ${activeAds.length} active ads.`);

        activeAds.forEach(ad => {
            logger.log(` - [${ad.id}] ${ad.title} (Status: ${ad.status}, URL: ${ad.audioUrl})`);
        });

        if (activeAds.length === 0) {
            logger.warn('⚠️ NO ACTIVE ADS FOUND! This is why getNextAd returns null.');

            // Check for ANY ads
            const allAds = await adsService.findAll(1, 100);
            logger.log(`ℹ️ Total ads in DB: ${allAds.total}`);
            allAds.ads.forEach(ad => {
                logger.log(`   - [${ad.id}] ${ad.title} (Status: ${ad.status})`);
            });
        }

    } catch (error) {
        logger.error('❌ Error checking ads:', error);
    }

    await app.close();
}

bootstrap();
