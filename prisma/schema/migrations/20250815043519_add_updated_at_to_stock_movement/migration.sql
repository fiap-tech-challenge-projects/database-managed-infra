/*
  Warnings:

  - Added the required column `updatedAt` to the `stock_movements` table without a default value. This is not possible if the table is not empty.

*/
-- AlterTable
ALTER TABLE "public"."stock_movements" ADD COLUMN     "updatedAt" TIMESTAMP(3) NOT NULL;
