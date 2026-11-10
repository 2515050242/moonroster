import { open } from 'node:fs/promises';

// File adapter only: validation and scheduling remain in the MoonBit engine.
const args = process.argv.slice(2);
function usage() {
  console.log('Usage: node cmd/solve.mjs INPUT.json');
  console.log('       node cmd/solve.mjs --repair PROBLEM.json');
  console.log('       node cmd/solve.mjs --audit PROBLEM.json CHOICES.json');
}

async function readInput(path) {
  const file = await open(path, 'r');
  try {
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
    return new TextDecoder('utf-8', { fatal: true }).decode(buffer.subarray(0, offset));
  } finally {
    await file.close();
  }
}

const legacy = args.length === 1 && !args[0].startsWith('--');
const repair = args.length === 2 && args[0] === '--repair';
const audit = args.length === 3 && args[0] === '--audit';
if (args.length === 1 && args[0] === '--help') {
  usage();
} else if (!legacy && !repair && !audit) {
  console.error('用法见 node cmd/solve.mjs --help。');
  process.exitCode = 64;
} else {
  try {
    const input = await readInput(legacy ? args[0] : args[1]);
    const engine = await import('../_build/js/release/build/cmd/web/web.js');
    const result = legacy ? engine.solve_json(input)
      : repair ? engine.repair_json(input)
      : engine.audit_repair_json(input, await readInput(args[2]));
    const codes = { ok: 0, optimal: 0, feasible: 0, unsatisfiable: 1, conflict: 1, invalid: 2, unknown: 3 };
    const status = JSON.parse(result).status;
    if (!Object.hasOwn(codes, status)) throw new Error('engine');
    console.log(result);
    process.exitCode = codes[status];
  } catch {
    console.error('无法读取输入或加载引擎。请确认文件为不超过 1 MiB 的 UTF-8 JSON，并先完成构建。');
    process.exitCode = 74;
  }
}
