import { Injectable, OnModuleInit, Logger } from '@nestjs/common';
import * as admin from 'firebase-admin';

@Injectable()
export class FirebaseService implements OnModuleInit {
    private readonly logger = new Logger(FirebaseService.name);

    async onModuleInit() {
        try {
            // Solo inicializar si no está ya inicializado
            if (admin.apps.length === 0) {
                // Inicializar con credenciales desde variables de entorno
                const projectId = process.env.FIREBASE_PROJECT_ID;
                const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
                const privateKey = process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n');

                if (!projectId || !clientEmail || !privateKey) {
                    // Firebase no configurado - usando Resend como método principal de emails
                    return;
                }

                admin.initializeApp({
                    credential: admin.credential.cert({
                        projectId,
                        clientEmail,
                        privateKey,
                    }),
                });

                this.logger.log('✅ Firebase Admin SDK initialized successfully');
            }
        } catch (error) {
            this.logger.error('❌ Error initializing Firebase Admin SDK:', error);
        }
    }

    /**
     * Get Firebase Admin instance
     */
    getAdmin() {
        return admin;
    }
}
