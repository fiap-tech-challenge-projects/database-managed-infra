/*
  Warnings:

  - You are about to alter the column `price` on the `services` table. The data in that column could be lost. The data in that column will be cast from `DoublePrecision` to `Integer`.
  - Made the column `description` on table `services` required. This step will fail if there are existing NULL values in that column.
  - Made the column `estimatedDuration` on table `services` required. This step will fail if there are existing NULL values in that column.

*/
-- AlterTable
ALTER TABLE "public"."services" ALTER COLUMN "description" SET NOT NULL,
ALTER COLUMN "description" SET DEFAULT '',
ALTER COLUMN "price" SET DATA TYPE INTEGER,
ALTER COLUMN "estimatedDuration" SET NOT NULL,
ALTER COLUMN "estimatedDuration" SET DEFAULT '00:00:00',
ALTER COLUMN "estimatedDuration" SET DATA TYPE TEXT;
