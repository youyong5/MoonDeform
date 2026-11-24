// Optional real-browser test: npm install --no-save playwright@1.62.1
// npx playwright install chromium
// Start: python3 -m http.server 8765 --directory dist
const {chromium} = require('playwright');
const assert = require('node:assert/strict');
(async () => {
  const options = {headless:true};
  if (process.env.CHROMIUM_PATH) options.executablePath = process.env.CHROMIUM_PATH;
  const browser = await chromium.launch(options);
  try {
    const page = await browser.newPage({viewport:{width:1280,height:900}});
    const errors = [];
    page.on('pageerror', e => errors.push(String(e)));
    await page.goto(process.env.DEMO_URL || 'http://127.0.0.1:8765');
    await page.waitForFunction(() => !!globalThis.moonDeform);
    await page.locator('#play').click();
    for (const kind of [0,1,2]) {
      await page.locator(`[data-scene="${kind}"]`).click();
      const result = await page.evaluate(kind => {
        const api = globalThis.moonDeform;
        api.reset(kind, 1e-4);
        for (let i=0;i<360;i++) api.step();
        return {error:api.error(),state:JSON.parse(api.snapshot())};
      },kind);
      assert.equal(result.error,'');
      assert.ok(result.state.points.every(p=>p.every(Number.isFinite)));
    }
    await page.locator('[data-scene="2"]').click();
    // Test actual pointer coordinate conversion while paused.
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
    await page.setViewportSize({width:390,height:844});
    assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
    assert.deepEqual(errors,[]);
    console.log('Browser scene switching, simulation, pointer drag and mobile layout passed.');
  } finally { await browser.close(); }
})().catch(e=>{console.error(e);process.exit(1);});
