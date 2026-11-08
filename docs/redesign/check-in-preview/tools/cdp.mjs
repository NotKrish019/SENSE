// Minimal Chrome DevTools Protocol driver for the Flutter web preview.
// node cdp.mjs '<json plan>'
// plan: {url, width, height, dpr, textScale, reducedMotion, out, actions:[...]}
// actions: {click:"aria label"} {key:"Tab"|"Enter"|" "} {wait:ms} {shot:"name"}
//          {type:"text"} (inserts text into the focused field)
//          {scroll:px} {eval:"js"} {fullshot:"name"} {focused:true}
import { spawn } from 'node:child_process';
import fs from 'node:fs';

const plan = JSON.parse(process.argv[2]);
const port = 9300 + Math.floor(Math.random() * 500);
const chrome = spawn('/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', [
  '--headless=new', `--remote-debugging-port=${port}`, '--no-first-run',
  ...(plan.gpu ? ['--use-angle=metal', '--enable-gpu', '--ignore-gpu-blocklist', '--enable-gpu-rasterization']
    : plan.swiftshader ? ['--use-angle=swiftshader', '--enable-unsafe-swiftshader'] : ['--disable-gpu']),
  '--hide-scrollbars', `--user-data-dir=${plan.out}/profile-${port}`, 'about:blank'], { stdio: 'ignore' });

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
let ws, id = 0; const pending = new Map();
const send = (method, params = {}) => new Promise((res, rej) => {
  const i = ++id; pending.set(i, { res, rej }); ws.send(JSON.stringify({ id: i, method, params }));
});
const log = [];
try {
  let targets;
  for (let t = 0; t < 50; t++) {
    try { targets = await (await fetch(`http://127.0.0.1:${port}/json`)).json(); break; } catch { await sleep(200); }
  }
  const page = targets.find((t) => t.type === 'page');
  ws = new WebSocket(page.webSocketDebuggerUrl);
  await new Promise((r) => ws.addEventListener('open', r));
  ws.addEventListener('message', (e) => {
    const m = JSON.parse(e.data);
    if (m.id && pending.has(m.id)) { const p = pending.get(m.id); pending.delete(m.id); m.error ? p.rej(new Error(JSON.stringify(m.error))) : p.res(m.result); }
    if (m.method === 'Runtime.consoleAPICalled') log.push(m.params.args.map((a) => a.value).join(' '));
    if (m.method === 'Runtime.exceptionThrown') log.push('EXC ' + JSON.stringify(m.params.exceptionDetails.exception?.description || m.params.exceptionDetails.text));
  });
  await send('Runtime.enable');
  await send('Page.enable');
  const W = plan.width, H = plan.height, dpr = plan.dpr || 1;
  await send('Emulation.setDeviceMetricsOverride', { width: W, height: H, deviceScaleFactor: dpr, mobile: W < 768 });
  if (plan.reducedMotion) await send('Emulation.setEmulatedMedia', { features: [{ name: 'prefers-reduced-motion', value: 'reduce' }] });
  if (plan.textScale && plan.textScale !== 1) {
    await send('Page.addScriptToEvaluateOnNewDocument', { source:
      `document.addEventListener('DOMContentLoaded',()=>{document.documentElement.style.fontSize='${16 * plan.textScale}px'});` });
  }
  await send('Page.navigate', { url: plan.url });
  await sleep(plan.boot || 6000);
  // Turn on the Flutter semantics tree so controls can be found by name.
  await send('Runtime.evaluate', { expression: `(()=>{const p=document.querySelector('flt-semantics-placeholder'); if(p){p.click(); return 'on'} return 'none'})()` });
  await sleep(800);

  const evalJs = async (expr) => (await send('Runtime.evaluate', { expression: expr, returnByValue: true, awaitPromise: true })).result.value;
  const rectOf = (label) => evalJs(`(()=>{const L=${JSON.stringify(label)};
      const all=[...document.querySelectorAll('flt-semantics[role], [aria-label]')].filter(e=>!e.querySelector('flt-semantics[role]'));
      const el=all.find(e=>e.getAttribute('aria-label')===L) || all.find(e=>(e.getAttribute('aria-label')||'').startsWith(L)) || all.find(e=>e.textContent.trim()===L) || all.find(e=>e.textContent.trim().startsWith(L));
      if(!el) return null; el.scrollIntoView({block:'center'}); const r=el.getBoundingClientRect(); return {x:r.x+r.width/2,y:r.y+r.height/2,w:r.width,h:r.height,label:el.getAttribute('aria-label'),sel:el.getAttribute('aria-selected')||el.getAttribute('aria-checked')};})()`);
  const mouse = async (type, x, y) => send('Input.dispatchMouseEvent', { type, x, y, button: 'left', clickCount: 1, pointerType: 'mouse' });
  const keys = { Tab: [9, 'Tab'], Enter: [13, 'Enter'], ' ': [32, 'Space'], ShiftTab: [9, 'Tab'] };

  for (const a of plan.actions) {
    if (a.wait) await sleep(a.wait);
    else if (a.click) {
      const r = await rectOf(a.click);
      if (!r) { log.push(`MISSING ${a.click}`); continue; }
      await sleep(250);
      const r2 = await rectOf(a.click);
      await mouse('mouseMoved', r2.x, r2.y); await mouse('mousePressed', r2.x, r2.y); await sleep(60); await mouse('mouseReleased', r2.x, r2.y); await sleep(80); await mouse('mouseMoved', 2, 2);
      log.push(`clicked ${a.click} @${Math.round(r2.x)},${Math.round(r2.y)} size ${Math.round(r2.w)}x${Math.round(r2.h)}`);
      await sleep(a.after || 700);
    } else if (a.type !== undefined) {
      await send('Input.insertText', { text: a.type });
      log.push(`typed ${a.type.length} chars`);
      await sleep(a.after || 500);
    } else if (a.key) {
      const [code, name] = keys[a.key];
      const mods = a.key === 'ShiftTab' ? 8 : 0;
      if (mods) await send('Input.dispatchKeyEvent', { type: 'rawKeyDown', windowsVirtualKeyCode: 16, code: 'ShiftLeft', key: 'Shift', modifiers: 8 });
      await send('Input.dispatchKeyEvent', { type: 'rawKeyDown', windowsVirtualKeyCode: code, code: name, key: a.key === 'ShiftTab' ? 'Tab' : a.key, modifiers: mods });
      if (a.key === ' ') await send('Input.dispatchKeyEvent', { type: 'char', text: ' ' });
      await send('Input.dispatchKeyEvent', { type: 'keyUp', windowsVirtualKeyCode: code, code: name, key: a.key === 'ShiftTab' ? 'Tab' : a.key, modifiers: mods });
      if (mods) await send('Input.dispatchKeyEvent', { type: 'keyUp', windowsVirtualKeyCode: 16, code: 'ShiftLeft', key: 'Shift', modifiers: 0 });
      await sleep(a.after || 250);
    } else if (a.scroll !== undefined) {
      await send('Input.dispatchMouseEvent', { type: 'mouseWheel', x: W / 2, y: H / 2, deltaX: 0, deltaY: a.scroll });
      await sleep(600);
    } else if (a.eval) {
      log.push('eval: ' + JSON.stringify(await evalJs(a.eval)));
    } else if (a.state) {
      log.push('state: ' + JSON.stringify(await evalJs(`[...document.querySelectorAll('flt-semantics[role]')].filter(e=>e.textContent.startsWith(${JSON.stringify(a.state)}) && !e.querySelector('flt-semantics[role]')).map(e=>e.getAttribute('role')+':'+e.textContent+(e.getAttribute('aria-current')==='true'?' [current]':''))`)));
    } else if (a.focused) {
      log.push('focused: ' + JSON.stringify(await evalJs(`(()=>{const e=document.activeElement; return e? (e.getAttribute('role')+':'+(e.getAttribute('aria-label')||e.textContent).slice(0,60)) : null})()`)));
    } else if (a.metrics) {
      log.push('metrics: ' + JSON.stringify(await evalJs(`({scrollW: document.documentElement.scrollWidth, innerW: innerWidth, dpr: devicePixelRatio, rootFont: getComputedStyle(document.documentElement).fontSize})`)));
    } else if (a.shot || a.fullshot) {
      const shot = await send('Page.captureScreenshot', { format: 'png' });
      fs.writeFileSync(`${plan.out}/${a.shot || a.fullshot}.png`, Buffer.from(shot.data, 'base64'));
      log.push(`shot ${a.shot || a.fullshot}`);
    }
  }
} catch (e) { log.push('ERROR ' + e.message); }
console.log(log.join('\n'));
chrome.kill('SIGKILL');
process.exit(0);
