/*
  Warnings:

  - You are about to drop the column `partId` on the `budget_items` table. All the data in the column will be lost.
  - You are about to drop the column `partId` on the `stock_movements` table. All the data in the column will be lost.
  - You are about to drop the `part_orders` table. If the table is not empty, all the data it contains will be lost.
  - You are about to drop the `parts` table. If the table is not empty, all the data it contains will be lost.
  - Added the required column `stockId` to the `stock_movements` table without a default value. This is not possible if the table is not empty.

*/
-- CreateEnum
CREATE TYPE "StockOrderStatus" AS ENUM ('REQUESTED', 'ORDERED', 'RECEIVED', 'CANCELLED');

-- DropForeignKey
ALTER TABLE "budget_items" DROP CONSTRAINT "budget_items_partId_fkey";

-- DropForeignKey
ALTER TABLE "part_orders" DROP CONSTRAINT "part_orders_partId_fkey";

-- DropForeignKey
ALTER TABLE "stock_movements" DROP CONSTRAINT "stock_movements_partId_fkey";

-- AlterTable
ALTER TABLE "budget_items" DROP COLUMN "partId",
ADD COLUMN     "stockId" TEXT;

-- AlterTable
ALTER TABLE "stock_movements" DROP COLUMN "partId",
ADD COLUMN     "stockId" TEXT NOT NULL;

-- DropTable
DROP TABLE "part_orders";

-- DropTable
DROP TABLE "parts";

-- DropEnum
DROP TYPE "PartOrderStatus";

-- CreateTable
CREATE TABLE "stock_items" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "sku" TEXT NOT NULL,
    "currentStock" INTEGER NOT NULL DEFAULT 0,
    "minStockLevel" INTEGER NOT NULL DEFAULT 5,
    "unitCost" DOUBLE PRECISION NOT NULL,
    "unitSalePrice" DOUBLE PRECISION NOT NULL,
    "supplier" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "stock_items_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "stock_orders" (
    "id" TEXT NOT NULL,
    "status" "StockOrderStatus" NOT NULL DEFAULT 'REQUESTED',
    "quantity" INTEGER NOT NULL,
    "orderDate" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expectedDeliveryDate" TIMESTAMP(3),
    "actualDeliveryDate" TIMESTAMP(3),
    "notes" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "stockId" TEXT NOT NULL,

    CONSTRAINT "stock_orders_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "stock_items_sku_key" ON "stock_items"("sku");

-- AddForeignKey
ALTER TABLE "budget_items" ADD CONSTRAINT "budget_items_stockId_fkey" FOREIGN KEY ("stockId") REFERENCES "stock_items"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "stock_movements" ADD CONSTRAINT "stock_movements_stockId_fkey" FOREIGN KEY ("stockId") REFERENCES "stock_items"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "stock_orders" ADD CONSTRAINT "stock_orders_stockId_fkey" FOREIGN KEY ("stockId") REFERENCES "stock_items"("id") ON DELETE CASCADE ON UPDATE CASCADE;
