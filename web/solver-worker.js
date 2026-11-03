import { solve_json } from '../_build/js/release/build/cmd/web/web.js';

self.onmessage = ({ data }) => {
  try {
    self.postMessage({ result: JSON.parse(solve_json(data)) });
  } catch {
    self.postMessage({ error: '计算未完成，请检查输入或减少问题规模。' });
  }
};
self.postMessage({ ready: true });
