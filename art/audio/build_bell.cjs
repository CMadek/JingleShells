// Original modal synthesis: a small brass ship's bell, two clapper strikes.
// Rebuild with: node art/audio/build_bell.cjs
const fs = require('fs');
const path = require('path');
const rate = 44100, duration = 3.6;
const samples = new Float64Array(Math.ceil(rate * duration));
const modes = [[783.99,1,1.15],[1568.8,.48,.85],[2169,.28,.65],[3142,.19,.42],[4258,.1,.25]];
let seed=49271;
for (const [start, strength] of [[.055,1],[.30,.65]]) {
 for(let i=Math.floor(start*rate);i<samples.length;i++) {
  const t=i/rate-start;
  let v=0;
  for(const [hz,level,decay] of modes) v+=level*Math.sin(2*Math.PI*hz*t)*Math.exp(-t/decay);
  seed=(Math.imul(seed,1664525)+1013904223)>>>0;
  v+=(seed/4294967296*2-1)*.22*Math.exp(-t/.009);
  samples[i]+=v*strength*(1-Math.exp(-t/.0015));
 }
}
let peak=0; for(const value of samples) peak=Math.max(peak,Math.abs(value));
const buffer=Buffer.alloc(44+samples.length*2);
buffer.write('RIFF'); buffer.writeUInt32LE(buffer.length-8,4);buffer.write('WAVEfmt ',8);
buffer.writeUInt32LE(16,16);buffer.writeUInt16LE(1,20);buffer.writeUInt16LE(1,22);
buffer.writeUInt32LE(rate,24);buffer.writeUInt32LE(rate*2,28);buffer.writeUInt16LE(2,32);buffer.writeUInt16LE(16,34);
buffer.write('data',36);buffer.writeUInt32LE(samples.length*2,40);
for(let i=0;i<samples.length;i++)buffer.writeInt16LE(Math.round(samples[i]/peak*.72*32767),44+i*2);
fs.writeFileSync(path.resolve(__dirname,'../../assets/audio/departure_bell.wav'),buffer);
console.log('Generated original 3.6-second mono bell chime, peak -2.85 dBFS.');
