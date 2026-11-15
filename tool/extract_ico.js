// Trích ảnh lớn nhất từ file .ico ra .png
// Cách chạy: node tool/extract_ico.js <input.ico> <output.png>
// ICO: 6-byte header (0,0,count), mỗi entry 16 byte: w,h,colors,res,planes,bpp,size,offset
// Frame hiện đại thường là PNG nhúng sẵn — copy thẳng; nếu là BMP thì báo lỗi.
const fs = require('fs');

const [input, output] = process.argv.slice(2);
if (!input || !output) {
  console.error('Usage: node extract_ico.js <input.ico> <output.png>');
  process.exit(1);
}

const buf = fs.readFileSync(input);
if (buf.readUInt16LE(0) !== 0 || buf.readUInt16LE(2) !== 1) {
  console.error('Không phải file ICO hợp lệ');
  process.exit(1);
}
const count = buf.readUInt16LE(4);
console.log('Số frame:', count);

let best = null;
for (let i = 0; i < count; i++) {
  const off = 6 + i * 16;
  const w = buf[off] === 0 ? 256 : buf[off];
  const h = buf[off + 1] === 0 ? 256 : buf[off + 1];
  const size = buf.readUInt32LE(off + 8);
  const dataOff = buf.readUInt32LE(off + 12);
  const isPng = buf.slice(dataOff, dataOff + 8).toString('hex') === '89504e470d0a1a0a';
  console.log(`  frame ${i}: ${w}x${h}, ${size} bytes, ${isPng ? 'PNG' : 'BMP'}`);
  if (best === null || w * h > best.w * best.h) {
    best = { w, h, size, dataOff, isPng };
  }
}

if (!best.isPng) {
  console.error('Frame lớn nhất là BMP — cần chuyển đổi riêng');
  process.exit(2);
}
fs.writeFileSync(output, buf.slice(best.dataOff, best.dataOff + best.size));
console.log(`ĐÃ LƯU: ${output} (${best.w}x${best.h})`);
