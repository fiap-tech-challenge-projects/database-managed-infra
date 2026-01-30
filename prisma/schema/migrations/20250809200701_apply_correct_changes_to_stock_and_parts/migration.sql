/*
  Warnings:

  - You are about to drop the column `stockId` on the `budget_items` table. All the data in the column will be lost.
  - Changed the type of `estimatedDuration` on the `services` table. No cast exists, the column would be dropped and recreated, which cannot be done if there is data, since the column is required.

*/
-- DropForeignKey
ALTER TABLE "budget_items" DROP CONSTRAINT "budget_items_stockId_fkey";

-- AlterTable
ALTER TABLE "budget_items" DROP COLUMN "stockId",
ADD COLUMN     "stockItemId" TEXT;

-- AlterTable
ALTER TABLE "services" DROP COLUMN "estimatedDuration",
ADD COLUMN     "estimatedDuration" DOUBLE PRECISION NOT NULL;

-- AddForeignKey
ALTER TABLE "budget_items" ADD CONSTRAINT "budget_items_stockItemId_fkey" FOREIGN KEY ("stockItemId") REFERENCES "stock_items"("id") ON DELETE SET NULL ON UPDATE CASCADE;
