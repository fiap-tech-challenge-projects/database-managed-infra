/*
  Warnings:

  - You are about to alter the column `unitCost` on the `stock_items` table. The data in that column could be lost. The data in that column will be cast from `DoublePrecision` to `Integer`.
  - You are about to alter the column `unitSalePrice` on the `stock_items` table. The data in that column could be lost. The data in that column will be cast from `DoublePrecision` to `Integer`.

*/
-- AlterTable
ALTER TABLE "public"."stock_items" ALTER COLUMN "unitCost" SET DATA TYPE INTEGER,
ALTER COLUMN "unitSalePrice" SET DATA TYPE INTEGER;
