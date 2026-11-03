const $ = (selector) => document.querySelector(selector);
const input = $('#input-data');
const runButton = $('#run');
const engineState = $('#engine-state');
const statusChip = $('#status-chip');
const summary = $('#result-summary');
const example = {
  rooms: [
    { id: 'r30', name: '明德楼 101', capacity: 30 },
    { id: 'r15', name: '研讨室 203', capacity: 15 },
  ],
  slots: [
    { id: 'mon-am', name: '周一上午' },
    { id: 'mon-pm', name: '周一下午' },
  ],
  courses: [
    { id: 'a', name: '数据库原理', teacher: '李老师', group: '计科一班', size: 20, allowed_slots: ['mon-pm'] },
    { id: 'b', name: '算法研讨', teacher: '李老师', group: '计科二班', size: 10, allowed_slots: ['mon-am'] },
    { id: 'c', name: '软件工程', teacher: '王老师', group: '计科一班', size: 10, allowed_slots: ['mon-am'] },
  ],
  node_limit: 100000,
};
let worker;
let running = false;
let submittedData;
let lastResult;
let formData;

function notice(message, kind = '') {
  engineState.textContent = message;
  engineState.className = `engine-state ${kind}`.trim();
}

function parseInput() {
  if (input.value.length > 262144) throw new Error('输入过大，最多支持 262144 个 UTF-16 码元。');
  return JSON.parse(input.value);
}

function resetResult() {
  if (running) {
    stopCalculation();
    notice('输入已更改，原计算已取消。');
  }
  lastResult = undefined;
  $('#empty-state').hidden = false;
  $('#result-content').hidden = true;
  statusChip.textContent = '等待运行';
}

function setInput(data) {
  input.value = JSON.stringify(data, null, 2);
  resetResult();
  if (!$('#form-editor').hidden) renderForm();
}

function element(tag, text, className) {
  const node = document.createElement(tag);
  if (text !== undefined) node.textContent = text;
  if (className) node.className = className;
  return node;
}

function syncForm() {
  input.value = JSON.stringify(formData, null, 2);
  resetResult();
}

function field(label, value, onInput, type = 'text') {
  const wrapper = element('label', undefined, 'form-field');
  wrapper.appendChild(element('span', label));
  const control = document.createElement('input');
  control.type = type;
  if (type === 'number') { control.min = '1'; control.step = '1'; }
  control.value = value ?? '';
  control.addEventListener('input', () => {
    onInput(type === 'number' && control.value !== '' ? Number(control.value) : control.value);
    syncForm();
  });
  wrapper.appendChild(control);
  return wrapper;
}

function choice(label, current, values, onChange, kind) {
  const wrapper = element('label', undefined, 'form-field');
  wrapper.appendChild(element('span', label));
  const select = document.createElement('select');
  for (const [value, text] of [['', '不固定'], ...values]) {
    const option = element('option', text);
    option.value = value;
    if (value) { option.dataset.refKind = kind; option.dataset.refId = value; }
    select.appendChild(option);
  }
  select.value = current || '';
  select.addEventListener('change', () => { onChange(select.value); syncForm(); });
  wrapper.appendChild(select);
  return wrapper;
}

function refreshReferenceNames() {
  document.querySelectorAll('[data-ref-kind]').forEach((node) => {
    const list = node.dataset.refKind === 'slot' ? formData.slots : formData.rooms;
    const record = list.find((item) => item.id === node.dataset.refId);
    if (!record) return;
    const name = record.name || record.id;
    if (node.tagName === 'OPTION') node.textContent = name;
    else node.lastChild.nodeValue = name;
  });
}

function nextId(prefix, items) {
  let n = 1;
  while (items.some((item) => item.id === `${prefix}-${n}`)) n += 1;
  return `${prefix}-${n}`;
}

function sectionHeading(title, count, add) {
  const header = element('div', undefined, 'form-section-head');
  const heading = element('strong', `${title} · ${count}`);
  const button = element('button', `＋ 添加${title}`, 'form-add');
  button.type = 'button';
  button.addEventListener('click', () => { add(); syncForm(); renderForm(); });
  header.append(heading, button);
  return header;
}

function removeButton(label, remove) {
  const button = element('button', '删除', 'form-remove');
  button.type = 'button';
  button.setAttribute('aria-label', `删除${label}`);
  button.addEventListener('click', () => { remove(); syncForm(); renderForm(); });
  return button;
}

function renderForm() {
  const target = $('#form-editor');
  target.replaceChildren();
  try {
    formData = parseInput();
    if (!formData || typeof formData !== 'object' || !['rooms', 'slots', 'courses'].every((key) => Array.isArray(formData[key]))) throw new Error('请提供 rooms、slots 和 courses 数组。');
    if (![...formData.rooms, ...formData.slots, ...formData.courses].every((item) => item && typeof item === 'object' && typeof item.id === 'string')) throw new Error('每条记录都需要字符串 id。');
    if (formData.rooms.length > 16 || formData.slots.length > 64 || formData.courses.length > 64) throw new Error('最多支持 16 个场地、64 个时段和 64 项课程。');
  } catch (error) {
    target.appendChild(element('p', `无法显示表单：${error.message} 请在高级 JSON 中修正。`, 'form-error'));
    return;
  }
  const slots = element('section', undefined, 'form-section');
  slots.appendChild(sectionHeading('时段', formData.slots.length, () => formData.slots.push({ id: nextId('slot', formData.slots), name: '' })));
  formData.slots.forEach((slot, index) => {
    const row = element('div', undefined, 'form-row compact');
    row.append(field('时段名称', slot.name, (value) => { slot.name = value; refreshReferenceNames(); }), removeButton(`时段 ${slot.name || slot.id}`, () => {
      formData.slots.splice(index, 1);
      for (const course of formData.courses) {
        if (Array.isArray(course.allowed_slots)) course.allowed_slots = course.allowed_slots.filter((id) => id !== slot.id);
        if (course.locked_slot === slot.id) delete course.locked_slot;
      }
    }));
    slots.appendChild(row);
  });
  target.appendChild(slots);
  const rooms = element('section', undefined, 'form-section');
  rooms.appendChild(sectionHeading('场地', formData.rooms.length, () => formData.rooms.push({ id: nextId('room', formData.rooms), name: '', capacity: 1 })));
  formData.rooms.forEach((room, index) => {
    const row = element('div', undefined, 'form-row');
    row.append(field('场地名称', room.name, (value) => { room.name = value; refreshReferenceNames(); }), field('容纳人数', room.capacity, (value) => { room.capacity = value; }, 'number'), removeButton(`场地 ${room.name || room.id}`, () => {
      formData.rooms.splice(index, 1);
      for (const course of formData.courses) if (course.locked_room === room.id) delete course.locked_room;
    }));
    rooms.appendChild(row);
  });
  target.appendChild(rooms);
  const courses = element('section', undefined, 'form-section');
  courses.appendChild(sectionHeading('课程', formData.courses.length, () => formData.courses.push({ id: nextId('course', formData.courses), name: '', teacher: '', group: '', size: 1, allowed_slots: [] })));
  formData.courses.forEach((course, index) => {
    const card = element('div', undefined, 'course-card');
    const title = element('div', undefined, 'course-title');
    title.append(element('strong', `课程 ${index + 1}`), removeButton(`课程 ${course.name || course.id}`, () => formData.courses.splice(index, 1)));
    card.appendChild(title);
    const grid = element('div', undefined, 'course-grid');
    grid.append(field('课程 / 任务名称', course.name, (value) => { course.name = value; }), field('教师 / 负责人', course.teacher, (value) => { course.teacher = value; }), field('班级 / 群组', course.group, (value) => { course.group = value; }), field('人数', course.size, (value) => { course.size = value; }, 'number'));
    card.appendChild(grid);
    const available = element('fieldset', undefined, 'available');
    available.appendChild(element('legend', '可用时段（至少选择一个）'));
    if (!formData.slots.length) available.appendChild(element('p', '请先添加时段。'));
    for (const slot of formData.slots) {
      const label = element('label');
      label.dataset.refKind = 'slot';
      label.dataset.refId = slot.id;
      const checkbox = document.createElement('input');
      checkbox.type = 'checkbox';
      checkbox.checked = Array.isArray(course.allowed_slots) && course.allowed_slots.includes(slot.id);
      checkbox.addEventListener('change', () => {
        if (!Array.isArray(course.allowed_slots)) course.allowed_slots = [];
        course.allowed_slots = course.allowed_slots.filter((id) => id !== slot.id);
        if (checkbox.checked) course.allowed_slots.push(slot.id);
        syncForm();
      });
      label.append(checkbox, document.createTextNode(slot.name || slot.id));
      available.appendChild(label);
    }
    card.appendChild(available);
    const locked = element('div', undefined, 'course-grid');
    locked.append(choice('固定时段（可选）', course.locked_slot, formData.slots.map((item) => [item.id, item.name || item.id]), (value) => { if (value) course.locked_slot = value; else delete course.locked_slot; }, 'slot'), choice('固定场地（可选）', course.locked_room, formData.rooms.map((item) => [item.id, item.name || item.id]), (value) => { if (value) course.locked_room = value; else delete course.locked_room; }, 'room'));
    card.appendChild(locked);
    courses.appendChild(card);
  });
  target.appendChild(courses);
  target.appendChild(field('搜索节点上限', formData.node_limit, (value) => { formData.node_limit = value; }, 'number'));
}

function showEditor(mode) {
  if (mode === 'form') {
    try { parseInput(); } catch (error) { notice(`JSON 格式有误：${error.message}`, 'error'); return; }
  }
  const isForm = mode === 'form';
  $('#form-editor').hidden = !isForm;
  $('#form-hint').hidden = !isForm;
  $('#json-editor').hidden = isForm;
  for (const [id, active] of [['#form-tab', isForm], ['#json-tab', !isForm]]) {
    $(id).classList.toggle('active', active);
    $(id).setAttribute('aria-pressed', String(active));
  }
  if (isForm) renderForm();
}

function downloadJson(data, filename) {
  const url = URL.createObjectURL(new Blob([JSON.stringify(data, null, 2)], { type: 'application/json;charset=utf-8' }));
  const link = document.createElement('a');
  link.href = url;
  link.download = filename;
  link.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

function updateResult(result, data) {
  lastResult = result;
  $('#empty-state').hidden = true;
  $('#result-content').hidden = false;
  const labels = { ok: '已生成', unsatisfiable: '无法安排', unknown: '尚未找到', invalid: '数据有误' };
  const messages = { ok: '已找到满足约束的安排。', unsatisfiable: '没有找到满足全部约束的安排，请检查可用时间、人员和场地。', unknown: '搜索已停止，尚不能判断是否存在可行方案。', invalid: '请检查输入数据后重试。' };
  const status = result.status;
  statusChip.textContent = labels[status] || '结果异常';
  summary.className = `result-summary ${status === 'ok' ? '' : status === 'unknown' ? 'warning' : 'error'}`.trim();
  summary.textContent = `${result.message || messages[status] || '引擎返回了未识别的结果。'}${Number.isInteger(result.nodes) ? ` 搜索节点：${result.nodes}。` : ''}`;
  $('#raw-result').textContent = JSON.stringify(result, null, 2);
  const rows = $('#result-rows');
  rows.replaceChildren();
  const assignments = Array.isArray(result.assignments) ? result.assignments : [];
  const find = (items, id) => Array.isArray(items) ? items.find((item) => item.id === id) : undefined;
  for (const assignment of assignments) {
    const course = find(data.courses, assignment.course);
    const slot = find(data.slots, assignment.slot);
    const room = find(data.rooms, assignment.room);
    const row = document.createElement('tr');
    for (const value of [course?.name || assignment.course, slot?.name || assignment.slot, room?.name || assignment.room, course?.teacher || '—', course?.group || '—']) {
      const cell = document.createElement('td');
      cell.textContent = String(value ?? '—');
      row.appendChild(cell);
    }
    rows.appendChild(row);
  }
  $('#table-wrap').hidden = assignments.length === 0;
}

input.addEventListener('input', resetResult);
$('#form-tab').addEventListener('click', () => showEditor('form'));
$('#json-tab').addEventListener('click', () => showEditor('json'));
$('#import-file').addEventListener('click', () => $('#file-input').click());
$('#export-input').addEventListener('click', () => {
  try { downloadJson(parseInput(), 'moonroster-input.json'); notice('输入数据已导出，可再次导入继续编辑。'); }
  catch (error) { notice(`无法导出：JSON 格式有误。${error.message}`, 'error'); }
});
$('#load-example').addEventListener('click', () => { setInput(example); notice('已载入示例，可直接生成排程。'); });
$('#format-input').addEventListener('click', () => {
  try { setInput(parseInput()); notice('数据格式已整理。'); }
  catch (error) { notice(`JSON 格式有误：${error.message}`, 'error'); }
});
$('#file-input').addEventListener('change', async (event) => {
  const file = event.target.files?.[0];
  if (!file) return;
  try {
    if (file.size > 1048576) throw new Error('文件不能超过 1 MiB。');
    const text = await file.text();
    if (text.length > 262144) throw new Error('输入不能超过 262144 个 UTF-16 码元。');
    setInput(JSON.parse(text)); notice('文件已导入。');
  }
  catch (error) { notice(`无法读取 JSON：${error.message}`, 'error'); }
  event.target.value = '';
});
runButton.addEventListener('click', () => {
  try {
    const data = parseInput();
    resetResult();
    submittedData = data;
    running = true;
    runButton.disabled = true;
    $('#cancel').hidden = false;
    notice('正在搜索，可以取消；修改输入也会停止本次计算。');
    worker.postMessage(input.value);
  } catch (error) { notice(`无法运行：${error.message}`, 'error'); }
});
$('#copy-result').addEventListener('click', async () => {
  try { await navigator.clipboard.writeText(JSON.stringify(lastResult, null, 2)); notice('结果已复制。'); }
  catch { notice('无法访问剪贴板，请展开“查看原始结果”手动复制。', 'error'); }
});
$('#download-result').addEventListener('click', () => {
  downloadJson(lastResult, 'moonroster-result.json');
});

function startWorker(announce = true) {
  runButton.disabled = true;
  try {
    const current = new Worker('./solver-worker.js', { type: 'module' });
    worker = current;
    current.onmessage = ({ data }) => {
      if (worker !== current) return;
      if (data.ready) {
        runButton.disabled = false;
        if (announce) notice('排程引擎已就绪。');
        return;
      }
      if (!running) return;
      running = false;
      runButton.disabled = false;
      $('#cancel').hidden = true;
      if (data.error) notice(data.error, 'error');
      else {
        updateResult(data.result, submittedData);
        notice('排程已结束，请查看结果。');
      }
      submittedData = undefined;
    };
    current.onerror = (event) => {
      event.preventDefault();
      if (worker !== current) return;
      current.terminate();
      running = false;
      submittedData = undefined;
      runButton.disabled = true;
      $('#cancel').hidden = true;
      notice('引擎未能运行。请确认构建成功后刷新页面。', 'error');
    };
  } catch {
    notice('当前浏览器无法启动后台计算，请使用支持 Web Worker 的浏览器。', 'error');
  }
}

function stopCalculation() {
  worker?.terminate();
  running = false;
  submittedData = undefined;
  $('#cancel').hidden = true;
  startWorker(false);
}

$('#cancel').addEventListener('click', () => {
  stopCalculation();
  notice('计算已取消，不能据此判断有解或无解。');
});

setInput(example);
startWorker();
