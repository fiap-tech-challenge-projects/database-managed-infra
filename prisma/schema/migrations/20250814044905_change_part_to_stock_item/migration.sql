/*
  Warnings:

  - The values [PART] on the enum `BudgetItemType` will be removed. If these variants are still used in the database, this will fail.

*/
-- AlterEnum
BEGIN;
CREATE TYPE "public"."BudgetItemType_new" AS ENUM ('SERVICE', 'STOCK_ITEM');
ALTER TABLE "public"."budget_items" ALTER COLUMN "type" TYPE "public"."BudgetItemType_new" USING ("type"::text::"public"."BudgetItemType_new");
ALTER TYPE "public"."BudgetItemType" RENAME TO "BudgetItemType_old";
ALTER TYPE "public"."BudgetItemType_new" RENAME TO "BudgetItemType";
DROP TYPE "public"."BudgetItemType_old";
COMMIT;
