
import { Client } from 'pg';

async function bootstrap() {
    const client = new Client({
        host: process.env.DB_HOST || 'localhost',
        port: parseInt(process.env.DB_PORT || '5432'),
        user: process.env.DB_USERNAME || 'vintage_user',
        password: process.env.DB_PASSWORD || 'vintage_password_2024',
        database: process.env.DB_DATABASE || 'vintage_music',
    });

    try {
        await client.connect();

        // Check specific ad details
        const res = await client.query(`
        SELECT id, title, status, audio_url, start_date, end_date, frequency_per_hour 
        FROM audio_ads 
        WHERE status = 'active'
    `);

        const now = new Date();
        console.log(`🕒 Current Server Time: ${now.toISOString()}`);

        res.rows.forEach(ad => {
            console.log('--------------------------------------------------');
            console.log(`🆔 ID: ${ad.id}`);
            console.log(`📝 Title: ${ad.title}`);
            console.log(`📶 Status: ${ad.status}`);
            console.log(`🔗 Audio URL: '${ad.audio_url}' (Length: ${ad.audio_url?.length})`);
            console.log(`📅 Start Date: ${ad.start_date ? ad.start_date.toISOString() : 'NULL'}`);
            console.log(`📅 End Date: ${ad.end_date ? ad.end_date.toISOString() : 'NULL'}`);
            console.log(`⏱️ Frequency/Hour: ${ad.frequency_per_hour}`);

            // Logic Check
            const startDateValid = !ad.start_date || new Date(ad.start_date) <= now;
            const endDateValid = !ad.end_date || new Date(ad.end_date) >= now;
            const urlValid = ad.audio_url && ad.audio_url !== '';

            console.log(`✅ Start Date Valid: ${startDateValid}`);
            console.log(`✅ End Date Valid: ${endDateValid}`);
            console.log(`✅ Audio URL Valid: ${urlValid}`);

            if (startDateValid && endDateValid && urlValid) {
                console.log('🎉 THIS AD SHOULD BE SELECTED!');
            } else {
                console.log('❌ THIS AD IS BEING FILTERED OUT.');
            }
        });

    } catch (err) {
        console.error(err);
    } finally {
        await client.end();
    }
}

bootstrap();
