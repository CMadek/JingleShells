// Original composition and synthesis for JingleShells. No samples or quoted tunes.
// Rebuild: node art/audio/build_menu.cjs
const fs = require('fs'), path = require('path');
const rate = 32000, bpm = 112, beat = 60 / bpm, bars = 32;
const frames = Math.round(bars * 3 * beat * rate);
const left = new Float64Array(frames), right = new Float64Array(frames);
const tau = Math.PI * 2, hz = midi => 440 * 2 ** ((midi - 69) / 12);
let seed = 251225;
const random = () => ((seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0) / 4294967296);
// Wrap note/reverb tails across the phrase boundary for a continuous loop.
function voice(start, duration, pan, level, sample) {
  const offset = Math.round(start * rate), count = Math.ceil(duration * rate);
  const l = Math.sqrt((1 - pan) / 2) * level, r = Math.sqrt((1 + pan) / 2) * level;
  for (let i = 0; i < count; i++) {
    const at = (offset + i) % frames, t = i / rate;
    const v = sample(t) * Math.min(1, (duration - t) / .04);
    left[at] += v * l; right[at] += v * r;
  }
}
function celesta(note, when, gain = .19, pan = -.12) {
  const f = hz(note);
  voice(when, 2.8, pan, gain, t => (1 - Math.exp(-t / .003)) * (
    Math.sin(tau * f * t) * Math.exp(-t / .72) +
    .32 * Math.sin(tau * f * 2 * t) * Math.exp(-t / .32) +
    .10 * Math.sin(tau * f * 3.99 * t) * Math.exp(-t / .13)));
}
function pluck(note, when, gain, pan) {
  const f = hz(note);
  voice(when, .95, pan, gain, t => (1 - Math.exp(-t / .006)) * Math.exp(-t / .22) * (
    Math.sin(tau * f * t) + .25 * Math.sin(tau * f * 2 * t) + .08 * Math.sin(tau * f * 3 * t)));
}
function pad(note, when, duration, pan) {
  const f = hz(note);
  voice(when, duration + .6, pan, .023, t => {
    const env = Math.min(1, t / .3) * Math.min(1, (duration + .6 - t) / .6);
    return env * (Math.sin(tau * f * t) + .3 * Math.sin(tau * f * 1.002 * t) +
      .18 * Math.sin(tau * f * 2 * t));
  });
}
function sleigh(when, accent, pan) {
  const phases = Array.from({length: 5}, () => random() * tau);
  voice(when, .19, pan, accent, t => {
    let v = 0;
    for (let j = 0; j < phases.length; j++)
      v += Math.sin(tau * [4321, 5713, 6899, 8171, 9349][j] * t + phases[j]);
    return v * .2 * Math.min(1, t / .002) * Math.exp(-t / .035);
  });
}
// Snowbound Dispatch: a lilting D-major waltz, with a B-minor middle phrase.
// Each row is a bar: [MIDI note, duration in quarter-note beats].
const melody = [
  [[78,.5],[81,.5],[76,1],[74,1]], [[73,.5],[76,.5],[81,1.5],[78,.5]],
  [[79,1],[78,.5],[76,.5],[74,1]], [[76,.5],[73,.5],[69,1],[73,1]],
  [[78,1],[81,.5],[83,.5],[81,1]], [[79,.5],[78,.5],[76,1],[73,1]],
  [[74,1],[78,1],[76,.5],[73,.5]], [[74,2],[0,1]],
  [[78,.5],[81,.5],[86,1],[85,.5],[81,.5]], [[83,1],[81,.5],[78,.5],[76,1]],
  [[79,.5],[83,.5],[81,1],[78,.5],[76,.5]], [[73,1],[76,1],[81,1]],
  [[83,.5],[81,.5],[78,1],[74,1]], [[76,1],[79,.5],[78,.5],[76,1]],
  [[73,.5],[76,.5],[81,1],[85,1]], [[86,2],[0,1]],
  [[78,1],[74,.5],[73,.5],[71,1]], [[73,.5],[76,.5],[78,1],[76,1]],
  [[79,1],[78,.5],[74,.5],[71,1]], [[73,1],[76,1],[81,1]],
  [[83,1],[78,1],[74,.5],[78,.5]], [[79,.5],[83,.5],[86,1],[83,1]],
  [[81,1],[79,.5],[76,.5],[73,1]], [[76,2],[0,.5],[81,.5]],
  [[86,1],[81,.5],[78,.5],[76,1]], [[79,.5],[78,.5],[76,1],[74,1]],
  [[83,1],[81,.5],[79,.5],[78,1]], [[76,.5],[73,.5],[69,1],[73,1]],
  [[74,.5],[78,.5],[81,1],[86,1]], [[83,.5],[79,.5],[78,1],[76,1]],
  [[73,.5],[76,.5],[81,1],[73,1]], [[74,2],[0,1]],
];
const chords = {
  D: [38, [62,66,69]], A: [33, [61,64,69]], G: [31, [59,62,67]],
  Bm: [35, [59,62,66]], Em: [40, [59,64,67]],
};
const harmony = ['D','A','G','A','Bm','G','A','D',
  'D','Bm','G','A','Bm','G','A','D',
  'Bm','Em','G','A','Bm','G','Em','A',
  'D','G','Bm','A','D','G','A','D'];
for (let bar = 0; bar < bars; bar++) {
  const start = bar * 3 * beat, [bass, chord] = chords[harmony[bar]];
  const lift = bar >= 8 && bar < 16 || bar >= 24;
  pluck(bass, start, .19, -.04);
  for (const note of chord) {
    pad(note, start, 3 * beat, (note % 3 - 1) * .35);
    for (const b of [1, 2]) pluck(note, start + b * beat, .055, .28);
  }
  let position = 0;
  for (const [note, length] of melody[bar]) {
    if (note) {
      celesta(note, start + position * beat, .19 + random() * .018);
      if (lift && position === 0) celesta(note + 12, start, .037, .45);
    }
    position += length;
  }
  if (Math.abs(position - 3) > .0001) throw new Error('Bad bar length: ' + bar);
  for (let b = 0; b < 6; b++) sleigh(start + b * beat / 2, b % 2 ? .018 : .033, b % 2 ? -.5 : .5);
}
// Quiet stereo early reflections, applied from the dry mix (no feedback drift).
const dryL = left.slice(), dryR = right.slice();
for (const [seconds, gain, cross] of [[.113,.14,true],[.227,.11,false],[.359,.08,true],[.491,.05,false]]) {
  const delay = Math.round(seconds * rate);
  for (let i = 0; i < frames; i++) {
    const j = (i + delay) % frames;
    left[j] += (cross ? dryR[i] : dryL[i]) * gain;
    right[j] += (cross ? dryL[i] : dryR[i]) * gain;
  }
}
let peak = 0, energy = 0;
for (let i = 0; i < frames; i++) peak = Math.max(peak, Math.abs(left[i]), Math.abs(right[i]));
const gain = .70 / peak, wav = Buffer.alloc(44 + frames * 4);
wav.write('RIFF'); wav.writeUInt32LE(wav.length - 8,4); wav.write('WAVEfmt ',8);
wav.writeUInt32LE(16,16); wav.writeUInt16LE(1,20); wav.writeUInt16LE(2,22);
wav.writeUInt32LE(rate,24); wav.writeUInt32LE(rate*4,28); wav.writeUInt16LE(4,32); wav.writeUInt16LE(16,34);
wav.write('data',36); wav.writeUInt32LE(frames*4,40);
for (let i = 0; i < frames; i++) {
  for (let channel = 0; channel < 2; channel++) {
    const value = (channel ? right[i] : left[i]) * gain;
    energy += value * value;
    wav.writeInt16LE(Math.round(value * 32767), 44 + i * 4 + channel * 2);
  }
}
const seam = Math.max(Math.abs(left[0]-left[frames-1]),Math.abs(right[0]-right[frames-1]))*gain;
if (seam > .025) throw new Error('Audible loop discontinuity: ' + seam);
fs.writeFileSync(path.resolve(__dirname,'../../assets/audio/snowbound_dispatch.wav'),wav);
console.log(JSON.stringify({title:'Snowbound Dispatch',seconds:frames/rate,bpm,peak:.70,rms:Math.sqrt(energy/(frames*2)),seam}));
