import { MigrationInterface, QueryRunner, TableColumn } from 'typeorm';

/**
 * Migración: Agregar campos de RevenueCat a la tabla users
 * 
 * Añade campos necesarios para gestionar suscripciones con RevenueCat:
 * - revenuecat_user_id: ID del usuario en RevenueCat
 * - revenuecat_customer_id: Customer ID generado por RevenueCat
 * - is_premium: Booleano para verificación rápida de estado premium
 * - premium_expires_at: Fecha de expiración de la suscripción premium
 * - last_revenuecat_sync: Última sincronización con RevenueCat
 */
export class AddRevenueCatFieldsToUsers1736458800000 implements MigrationInterface {
    public async up(queryRunner: QueryRunner): Promise<void> {
        // 1. Campo: ID del usuario en RevenueCat (normalmente igual al ID de nuestra DB)
        await queryRunner.addColumn(
            'users',
            new TableColumn({
                name: 'revenuecat_user_id',
                type: 'varchar',
                length: '255',
                isNullable: true,
                comment: 'App User ID usado en RevenueCat',
            }),
        );

        // 2. Campo: Customer ID generado por RevenueCat
        await queryRunner.addColumn(
            'users',
            new TableColumn({
                name: 'revenuecat_customer_id',
                type: 'varchar',
                length: '255',
                isNullable: true,
                isUnique: true,
                comment: 'RevenueCat original customer ID',
            }),
        );

        // 3. Campo: Estado premium (booleano para queries rápidas)
        await queryRunner.addColumn(
            'users',
            new TableColumn({
                name: 'is_premium',
                type: 'boolean',
                default: false,
                isNullable: false,
                comment: 'Indica si el usuario tiene suscripción premium activa',
            }),
        );

        // 4. Campo: Fecha de expiración de premium
        await queryRunner.addColumn(
            'users',
            new TableColumn({
                name: 'premium_expires_at',
                type: 'timestamp',
                isNullable: true,
                comment: 'Fecha de expiración de la suscripción premium',
            }),
        );

        // 5. Campo: Última sincronización con RevenueCat
        await queryRunner.addColumn(
            'users',
            new TableColumn({
                name: 'last_revenuecat_sync',
                type: 'timestamp',
                isNullable: true,
                comment: 'Última vez que se sincronizó el estado con RevenueCat',
            }),
        );

        // 6. Crear índice para búsquedas rápidas por premium
        await queryRunner.query(`
      CREATE INDEX idx_users_is_premium 
      ON users(is_premium)
    `);

        // 7. Crear índice para búsquedas por revenuecat_customer_id
        await queryRunner.query(`
      CREATE INDEX idx_users_revenuecat_customer_id 
      ON users(revenuecat_customer_id)
    `);

        console.log('✅ Campos de RevenueCat agregados exitosamente a la tabla users');
    }

    public async down(queryRunner: QueryRunner): Promise<void> {
        // Eliminar índices
        await queryRunner.query(`DROP INDEX IF EXISTS idx_users_is_premium`);
        await queryRunner.query(`DROP INDEX IF EXISTS idx_users_revenuecat_customer_id`);

        // Eliminar columnas en orden inverso
        await queryRunner.dropColumn('users', 'last_revenuecat_sync');
        await queryRunner.dropColumn('users', 'premium_expires_at');
        await queryRunner.dropColumn('users', 'is_premium');
        await queryRunner.dropColumn('users', 'revenuecat_customer_id');
        await queryRunner.dropColumn('users', 'revenuecat_user_id');

        console.log('✅ Campos de RevenueCat eliminados de la tabla users');
    }
}
