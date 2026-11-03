import { open } from 'node:fs/promises';

// File adapter only: validation and scheduling remain in the MoonBit engine.
const args = process.argv.slice(2);
if (args.length === 1 && args[0] === '--help') {
  console.log('Usage: node cmd/solve.mjs INPUT.json');
  console.log('Exit codes: 0 ok, 1 unsatisfiable, 2 invalid, 3 unknown, 64 usage, 74 read error.');
} else if (args.length !== 1 || args[0].startsWith('--')) {
  console.error('Usage: node cmd/solve.mjs INPUT.json');
  process.exitCode = 64;
} else {
  let file;
  try {
    file = await open(args[0], 'r');
    const info = await file.stat();
    if (!info.isFile() || info.size > 1048576) throw new Error('input');
    // Bound the read even if a file grows after stat().
    const buffer = Buffer.alloc(1048577);
    let offset = 0;
    while (offset < buffer.length) {
      const { bytesRead } = await file.read(buffer, offset, buffer.length - offset, null);
      if (!bytesRead) break;
      offset += bytesRead;
    }
    if (offset > 1048576) throw new Error('input');
    const input = new TextDecoder('utf-8', { fatal: true }).decode(buffer.subarray(0, offset));
    const { solve_json } = await import('../_build/js/release/build/cmd/web/web.js');
    const result = solve_json(input);
    const codes = { ok: 0, unsatisfiable: 1, invalid: 2, unknown: 3 };
    const status = JSON.parse(result).status;
    if (!(status in codes)) throw new Error('engine');
    console.log(result);
    process.exitCode = codes[status];
  } catch {
    console.error('无法读取输入或加载引擎。请确认文件为不超过 1 MiB 的 UTF-8 JSON，并先完成构建。');
    process.exitCode = 74;
  } finally {
    await file?.close();
  }
}
