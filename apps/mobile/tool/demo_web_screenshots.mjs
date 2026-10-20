// Drives the Demo-mode web build in headless Chromium (390x844) and saves
// screenshots of the real running app. Needs Node + Playwright and a served build:
//   tool/serve_demo_web.sh --build &            # http://localhost:8080
//   NODE_PATH=/path/to/node_modules node tool/demo_web_screenshots.mjs
// Env: URL (default http://localhost:8080/), OUT (default ../../docs/ux/demo),
//      PLAYWRIGHT (module path), CHROME (executable), ROBOTO (offline font).
import fs from 'fs';
import path from 'path';

const pw = process.env.PLAYWRIGHT || 'playwright';
const { chromium } = await import(pw);
const URL = process.env.URL || 'http://localhost:8080/';
const OUT = process.env.OUT || path.resolve('../../docs/ux/demo');
const ROBOTO = process.env.ROBOTO || '/opt/flutter/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf';
fs.mkdirSync(OUT, { recursive: true });

const browser = await chromium.launch({
  executablePath: process.env.CHROME || undefined,
  args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'],
});
const page = await (await browser.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2 })).newPage();
page.on('pageerror', (e) => console.log('pageerror', e.message.slice(0, 200)));
if (fs.existsSync(ROBOTO)) {
  const roboto = fs.readFileSync(ROBOTO);
  await page.route('https://fonts.gstatic.com/**', (r) => r.fulfill({ body: roboto, contentType: 'font/ttf' }));
}
await page.goto(URL);
// Flutter paints to a canvas; its accessibility tree gives clickable DOM nodes.
await page.waitForSelector('flt-semantics-placeholder', { state: 'attached', timeout: 90000 });
await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
await page.waitForTimeout(1500);

let n = 0;
const shot = async (name) => {
  await page.waitForTimeout(900);
  const file = path.join(OUT, `${String(++n).padStart(2, '0')}_${name}.png`);
  await page.screenshot({ path: file });
  console.log('saved', file);
};
const btn = (name, opts = {}) => page.getByRole('button', { name, ...opts }).first();
const click = async (name) => { await btn(name).click(); await page.waitForTimeout(700); };
const text = (t) => page.locator('flt-semantics').filter({ hasText: t }).last();

await shot('welcome');
await click('Get started');
await page.getByRole('radio', { name: /woman/ }).click();
await click('Birth date');
await click('1996');
await click('OK');
await shot('who_you_are');
await click('Start looking');
await page.waitForTimeout(2500);
await shot('discover_as_guest');
await page.mouse.click(160, 380); // open the card's profile
await page.waitForTimeout(1500);
await shot('profile_limited');
await click('Send interest');
await shot('gate_sign_in_to_say_hello');
await click('Sign in or create an account');
await page.mouse.click(195, 210);
await page.keyboard.type('772000111', { delay: 30 });
await shot('phone');
await click('Send code');
await shot('code_any_six_digits');
await page.keyboard.type('482913', { delay: 50 });
await page.waitForTimeout(1800);
await page.mouse.click(195, 245);
await page.keyboard.type('Grace', { delay: 30 });
await click('Select all');
await shot('about_you_prefilled');
await click('Continue');
await page.waitForTimeout(2500);
await shot('back_at_profile_after_sign_in');
await click('Send interest');
await shot('verify_sheet');
await click('Start verification');
await shot('verify_id_type');
await click('Start verification');
await click('Open camera');
await shot('verify_capture_demo');
await page.waitForTimeout(3500);
await shot('verify_pending');
await page.waitForTimeout(9000);
await shot('verified');

// Jump to a member who has used 2 of 3 free interests, via the controls.
await page.evaluate(() => document.querySelector('[aria-label="Demo controls"]')?.click());
await page.getByRole('button', { name: 'Demo controls' }).first().click().catch(() => {});
await page.waitForTimeout(800);
await shot('demo_controls');
await text('Verified free member').click();
await page.waitForTimeout(3500);
await shot('verified_free_discover');
await page.getByRole('tab', { name: /Interests/ }).click();
await page.waitForTimeout(1500);
await shot('interests_received');
await page.getByRole('tab', { name: /Matches/ }).click();
await page.waitForTimeout(1500);
await shot('matches_unread');
await browser.close();
