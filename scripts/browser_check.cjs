// Optional browser gate. Requires Playwright and its Chromium installation.
// Starts an ephemeral loopback server unless DEMO_URL is explicitly supplied.
const {chromium} = require('playwright');
const assert = require('node:assert/strict');
const http = require('node:http');
const fs = require('node:fs/promises');
const path = require('node:path');

async function serve() {
  const root = path.resolve(__dirname, '../dist');
  const server = http.createServer(async (req, res) => {
    try {
      const relative = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);
      const file = path.resolve(root, '.' + (relative === '/' ? '/index.html' : relative));
      if (!file.startsWith(root + path.sep)) { res.writeHead(403); res.end(); return; }
      const data = await fs.readFile(file);
      res.setHeader('Content-Type', file.endsWith('.js') ? 'text/javascript; charset=utf-8' : 'text/html; charset=utf-8');
      res.end(data);
    } catch { res.writeHead(404); res.end(); }
  });
  await new Promise((resolve,reject) => {
    server.once('error',reject);
    server.listen(0,'127.0.0.1',resolve);
  });
  return {server,url:`http://127.0.0.1:${server.address().port}`};
}

async function exercise(browser, url, mobile) {
  const page = await browser.newPage({viewport:mobile?{width:390,height:844}:{width:1280,height:900}});
  try {
    const errors = [];
    page.on('pageerror', e => errors.push(String(e)));
    await page.goto(url);
    await page.waitForFunction(() => !!globalThis.moonDeform);
    await page.locator('#play').click();
    for (const kind of [0,1,2]) {
      await page.locator(`[data-scene="${kind}"]`).click();
      const result = await page.evaluate(kind => {
        const api = globalThis.moonDeform;
        api.reset(kind,1e-4);
        for (let i=0;i<360;i++) api.step();
        return {error:api.error(),state:JSON.parse(api.snapshot())};
      },kind);
      assert.equal(result.error,'');
      assert.ok(result.state.points.every(p=>p.every(Number.isFinite)));
    }
    await page.locator('[data-scene="2"]').click();
    await page.locator('#step').click();
    const first = await page.evaluate(()=>JSON.parse(moonDeform.snapshot()).time);
    await page.locator('#step').click();
    const second = await page.evaluate(()=>JSON.parse(moonDeform.snapshot()).time);
    assert.ok(Math.abs(second-first-1/60)<1e-9);
    // Mobile controls are below the canvas; return to the visible drag target.
    await page.locator('#view').scrollIntoViewIfNeeded();
    const point = await page.evaluate(() => {
      const p=JSON.parse(moonDeform.snapshot()).points[5];
      const b=document.getElementById('view').getBoundingClientRect();
      const s=Math.min(b.width/10,b.height/6);
      return {x:b.x+b.width/2+p[0]*s,y:b.y+b.height-36-p[1]*s};
    });
    const before = await page.evaluate(()=>JSON.parse(moonDeform.snapshot()).points[5]);
    await page.mouse.move(point.x,point.y);
    await page.mouse.down();
    await page.mouse.move(point.x+30,point.y-15,{steps:3});
    await page.mouse.up();
    const after = await page.evaluate(()=>JSON.parse(moonDeform.snapshot()).points[5]);
    assert.ok(Math.hypot(after[0]-before[0],after[1]-before[1])>0.1);
    const beforeTune = await page.evaluate(()=>JSON.parse(moonDeform.snapshot()));
    await page.locator('#softness').focus();
    await page.locator('#softness').press('ArrowRight');
    const afterTune = await page.evaluate(()=>JSON.parse(moonDeform.snapshot()));
    assert.deepEqual(afterTune.points, beforeTune.points);
    assert.deepEqual(afterTune.edges, beforeTune.edges);
    assert.equal(afterTune.time, beforeTune.time);
    assert.equal(afterTune.energy, beforeTune.energy);
    assert.notEqual(afterTune.material.distance, beforeTune.material.distance);
    assert.equal(afterTune.material.area, afterTune.material.distance * .01);
    assert.equal(afterTune.material.bend, beforeTune.material.bend);
    assert.notEqual(await page.locator('#stretch-error').innerText(), '—');
    await page.locator('#step').click();
    const continuedTime = await page.evaluate(()=>JSON.parse(moonDeform.snapshot()).time);
    assert.ok(Math.abs(continuedTime-afterTune.time-1/60)<1e-9);
    await page.locator('#reset').click();
    assert.equal(await page.evaluate(()=>JSON.parse(moonDeform.snapshot()).time), 0);
    assert.equal(await page.locator('#error').innerText(),'');
    assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
    assert.deepEqual(errors,[]);
  } finally { await page.close(); }
}

(async () => {
  let local, browser;
  try {
    if (!process.env.DEMO_URL) local=await serve();
    const base=(process.env.DEMO_URL||local.url).replace(/\/$/,'');
    const options={headless:true};
    if(process.env.CHROMIUM_PATH)options.executablePath=process.env.CHROMIUM_PATH;
    browser=await chromium.launch(options);
    await exercise(browser,base+'/',false);
    await exercise(browser,base+'/MoonDeform-demo.html',true);
    console.log('Desktop static site and mobile single-file browser checks passed.');
    console.log(JSON.stringify({result:'passed',browser:browser.version(),scenarios:['desktop-static','mobile-standalone']}));
  } finally {
    if(browser)await browser.close();
    if(local)await new Promise(resolve=>local.server.close(resolve));
  }
})().catch(e=>{console.error(e);process.exitCode=1;});
