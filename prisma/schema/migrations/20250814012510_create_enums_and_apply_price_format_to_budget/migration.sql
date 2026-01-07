/*
  Warnings:

  - You are about to alter the column `unitPrice` on the `budget_items` table. The data in that column could be lost. The data in that column will be cast from `DoublePrecision` to `Integer`.
  - You are about to alter the column `totalPrice` on the `budget_items` table. The data in that column could be lost. The data in that column will be cast from `DoublePrecision` to `Integer`.
  - You are about to alter the column `totalAmount` on the `budgets` table. The data in that column could be lost. The data in that column will be cast from `DoublePrecision` to `Integer`.
  - The `deliveryMethod` column on the `budgets` table would be dropped and recreated. This will lead to data loss if there is data in the column.
  - Changed the type of `type` on the `budget_items` table. No cast exists, the column would be dropped and recreated, which cannot be done if there is data, since the column is required.

*/
-- CreateEnum
CREATE TYPE "public"."DeliveryMethod" AS ENUM ('EMAIL', 'SMS', 'WHATSAPP', 'PHONE', 'IN_PERSON');

-- CreateEnum
CREATE TYPE "public"."BudgetItemType" AS ENUM ('SERVICE', 'PART');

-- AlterTable
ALTER TABLE "public"."budget_items" DROP COLUMN "type",
ADD COLUMN     "type" "public"."BudgetItemType" NOT NULL,
ALTER COLUMN "unitPrice" SET DATA TYPE INTEGER,
ALTER COLUMN "totalPrice" SET DATA TYPE INTEGER;

-- AlterTable
ALTER TABLE "public"."budgets" ALTER COLUMN "totalAmount" SET DATA TYPE INTEGER,
DROP COLUMN "deliveryMethod",
ADD COLUMN     "deliveryMethod" "public"."DeliveryMethod";
