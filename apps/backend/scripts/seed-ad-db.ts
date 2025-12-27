
import { Client } from 'pg';
import { v4 as uuidv4 } from 'uuid';

async function bootstrap() {
    const client = new Client({
        host: process.env.DB_HOST || 'localhost',
        port: parseInt(process.env.DB_PORT || '5432'),
        user: process.env.DB_USERNAME || 'vintage_user',
        password: process.env.DB_PASSWORD || 'vintage_password_2024',
        database: process.env.DB_DATABASE || 'vintage_music',
    });

    try {
        console.log('🔌 Connecting to database...');
        await client.connect();
        console.log('✅ Connected.');

        // 1. Check for active ads
        const checkRes = await client.query(`SELECT count(*) FROM audio_ads WHERE status = 'active'`);
        const count = parseInt(checkRes.rows[0].count);
        console.log(`📊 Current Active Ads: ${count}`);

        if (count === 0) {
            console.log('🌱 No active ads found. Seeding one now...');

            const seedAd = {
                id: uuidv4(),
                title: 'Anuncio Semilla (Backend Seed)',
                description: 'Anuncio insertado por script de debug',
                audio_url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3', // Valid Audio
                cover_image_url: 'https://picsum.photos/500/500',
                advertiser_name: 'Vintage Music Debugger',
                duration_seconds: 30,
                file_size_bytes: 1024 * 1024,
                status: 'active',
                targeting: 'all',
                frequency_per_hour: 50,
                priority: 100,
                is_skippable: true,
                skip_after_seconds: 5,
                created_at: new Date(),
                updated_at: new Date()
            };

            const insertQuery = `
        INSERT INTO audio_ads (
          id, title, description, audio_url, cover_image_url, advertiser_name, 
          duration_seconds, file_size_bytes, status, targeting, frequency_per_hour, 
          priority, is_skippable, skip_after_seconds, created_at, updated_at
        ) VALUES (
          $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16
        ) RETURNING id;
      `;

            const values = [
                seedAd.id, seedAd.title, seedAd.description, seedAd.audio_url,
                seedAd.cover_image_url, seedAd.advertiser_name, seedAd.duration_seconds,
                seedAd.file_size_bytes, seedAd.status, seedAd.targeting, seedAd.frequency_per_hour,
                seedAd.priority, seedAd.is_skippable, seedAd.skip_after_seconds,
                seedAd.created_at, seedAd.updated_at
            ];

            const res = await client.query(insertQuery, values);
            console.log(`✅ Seed Ad Inserted! ID: ${res.rows[0].id}`);

        } else {
            console.log('ℹ️ Ads already exist. Querying them to show details:');
            const ads = await client.query(`SELECT id, title, status, audio_url FROM audio_ads WHERE status = 'active'`);
            ads.rows.forEach(ad => {
                console.log(` - [${ad.title}] ${ad.id} (${ad.status}) URL: ${ad.audio_url}`);
            });
        }

    } catch (err) {
        console.error('❌ Error executing seed script:', err);
    } finally {
        await client.end();
    }
}

bootstrap();
