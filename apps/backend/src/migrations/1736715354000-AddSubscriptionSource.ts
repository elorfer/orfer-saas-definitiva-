import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddSubscriptionSource1736715354000 implements MigrationInterface {
    name = 'AddSubscriptionSource1736715354000';

    public async up(queryRunner: QueryRunner): Promise<void> {
        // Agregar columna subscription_source
        await queryRunner.query(`
      ALTER TABLE "users" 
      ADD COLUMN "subscription_source" VARCHAR(20) DEFAULT 'manual'
    `);

        // Actualizar usuarios existentes: si tienen revenuecatCustomerId, marcarlos como 'revenuecat'
        await queryRunner.query(`
      UPDATE "users" 
      SET "subscription_source" = 'revenuecat' 
      WHERE "revenuecat_customer_id" IS NOT NULL
    `);

        // Crear índice para búsquedas rápidas
        await queryRunner.query(`
      CREATE INDEX "IDX_users_subscription_source" 
      ON "users" ("subscription_source")
    `);
    }

    public async down(queryRunner: QueryRunner): Promise<void> {
        // Revertir cambios
        await queryRunner.query(`DROP INDEX "IDX_users_subscription_source"`);
        await queryRunner.query(`ALTER TABLE "users" DROP COLUMN "subscription_source"`);
    }
}
