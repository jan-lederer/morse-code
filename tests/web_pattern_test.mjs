import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import vm from 'node:vm';

const html = await readFile(process.argv[2] ?? new URL('../web/index.html', import.meta.url), 'utf8');
const script = html.match(/<script>([\s\S]*?)<\/script>/)[1];

function fixture() {
  const oscillators = [], gains = [], vibrations = [];
  let resume, now = 1000;
  class AudioContext {
    constructor() { this.currentTime = 4; fixture.context = this; }
    destination = {};
    resume() { return new Promise(resolve => { resume = resolve; }); }
    createGain() {
      const events = [];
      const gain = {events, gain: {
        setValueAtTime(value, time) { events.push({value, time, ramp: false}); },
        linearRampToValueAtTime(value, time) { events.push({value, time, ramp: true}); },
      }, connect() {}, disconnect() {}};
      gains.push(gain); return gain;
    }
    createOscillator() {
      const oscillator = {frequency: {}, starts: [], stops: [],
        connect() {}, disconnect() {},
        start(time) { this.starts.push(time); }, stop(time) { this.stops.push(time); }};
      oscillators.push(oscillator); return oscillator;
    }
  }
  const window = {AudioContext, addEventListener() {}};
  vm.runInNewContext(script, {window, navigator: {vibrate(pattern) {vibrations.push(pattern);}},
    performance: {now: () => now}, setTimeout() {throw Error('Pattern must not use wall-clock pulse timers');}});
  return {window, oscillators, gains, vibrations,
    resume() {now += 350; fixture.context.currentTime += .35; resume();}};
}

for (const [code, expected] of [['..', [150,100,100,100,100]], ['.-', [150,100,100,300,100]]]) {
  const f = fixture();
  const playback = f.window.ditPlayPattern(code, true, true);
  assert.equal(f.oscillators.length, 0, 'No pulse before cold AudioContext is ready');
  assert.equal(f.vibrations.filter(Array.isArray).length, 0);
  f.resume();
  assert.equal(await playback, 150);
  assert.deepEqual(Array.from(f.vibrations.find(Array.isArray)), expected);
  const events = f.gains[0].events;
  const pulses = events.filter(e => e.ramp && e.value === .12);
  assert.equal(pulses.length, 2);
  const silence = events.find(e => e.ramp && e.value === 0);
  assert.ok(Math.abs((pulses[1].time - .002) - silence.time - .1) < 1e-9, '100ms silence is encoded between tones');
  assert.ok(Math.abs(pulses[0].time - .002 - 4.35 - .15) < 1e-9);
  const stopped = f.oscillators[0].stops[0];
  assert.ok(Math.abs(stopped - 4.35 - expected.reduce((a,b)=>a+b,0)/1000) < 1e-9);
}

{
  const f = fixture();
  const pending = f.window.ditPlayPattern('..', true, true);
  f.window.ditStopPattern();
  f.resume();
  assert.equal(await pending, -1);
  assert.equal(f.oscillators.length, 0, 'Cancelled cold resume must never start late');
  assert.equal(f.vibrations.filter(Array.isArray).length, 0);
}

{
  const f = fixture();
  const first = f.window.ditPlayPattern('..', true, true); f.resume(); await first;
  const old = f.oscillators[0];
  const second = f.window.ditPlayPattern('.-', true, true); f.resume(); await second;
  old.onended();
  f.window.ditStopPattern();
  assert.ok(f.oscillators[1].stops.includes(undefined), 'Old completion must not lose the new oscillator');
}
console.log('Passed 4 web pattern cases: cold A/I schedules, cancellation while resuming, and rapid replacement.');
