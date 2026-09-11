# CLAUDE.md — คู่มือ/คำสั่งประจำโปรเจกต์

โปรเจกต์: **EA_ATR_News** — Expert Advisor (MT5) แนว News Straddle Breakout + ATR

## ภาพรวมโค้ด
- `EA_ATR_News.mq5` — ไฟล์ EA หลัก (ภาษา MQL5)
- `README.md` — วิธีติดตั้ง / พารามิเตอร์ / ตรรกะการทำงาน

## Workflow อัตโนมัติ (สำคัญ)
เมื่อ **แก้ไขโค้ดเสร็จในแต่ละครั้ง** ให้ Claude ทำตามลำดับนี้โดยอัตโนมัติ:

1. `git add -A`
2. `git commit` พร้อมข้อความสื่อความหมายชัดเจน
3. `git push -u origin <working-branch>` (retry แบบ exponential backoff ถ้าเน็ตล้ม)
4. **merge เข้า `main`**:
   - ถ้ายังไม่มี `main` ให้สร้าง `main` จาก branch งานปัจจุบัน
   - ถ้ามี `main` แล้ว ให้ merge branch งาน → `main` แล้ว `git push origin main`
5. รายงานผลว่า commit/push/merge สำเร็จหรือไม่ พร้อม hash และลิงก์

> หมายเหตุ: ทำ merge เข้า `main` ได้เลยตามที่เจ้าของ repo อนุญาตไว้ในไฟล์นี้
> โดยไม่ต้องถามซ้ำทุกครั้ง เว้นแต่เกิด merge conflict ที่ต้องตัดสินใจ

## ข้อควรระวัง
- อย่าลบไฟล์ที่ไม่ได้สร้างเองโดยไม่ตรวจสอบก่อน
- คอมเมนต์/ข้อความ commit เป็นภาษาไทยได้
- ถ้า merge เข้า `main` เกิด conflict ให้หยุดและถามผู้ใช้ก่อน
