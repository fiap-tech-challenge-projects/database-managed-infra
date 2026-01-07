/*
  Warnings:

  - You are about to drop the column `registrationDate` on the `clients` table. All the data in the column will be lost.
  - You are about to drop the column `registrationDate` on the `vehicles` table. All the data in the column will be lost.

*/
-- AlterTable
ALTER TABLE "public"."clients" DROP COLUMN "registrationDate",
ADD COLUMN     "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;

-- AlterTable
ALTER TABLE "public"."vehicles" DROP COLUMN "registrationDate",
ADD COLUMN     "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;
