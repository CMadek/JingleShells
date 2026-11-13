// Original synthesized aircraft effects. Run: node art/audio/build_flight.cjs
const fs = require('fs'), path = require('path');
const rate = 32000, out = path.resolve(__dirname, '../../assets/audio');
let seed = 813;
function noise(n, smoothing) {
  const white = Float64Array.from({length:n}, () => {
    seed=(Math.imul(seed,1664525)+1013904223)>>>0;
    return seed/2147483648-1;
  });
  const result = new Float64Array(n);
  let state=0;
  // Two passes settle the filter into a periodic state for seamless loops.
  for(let i=0;i<n*2;i++) {
    state += smoothing*(white[i%n]-state);
    if(i>=n)result[i-n]=state;
  }
  return result;
}
function write(name, seconds, fn, loop=false) {
  const n=Math.round(seconds*rate), low=noise(n,.035), high=noise(n,.35);
  const data=new Float64Array(n);
  let peak=0, energy=0;
  for(let i=0;i<n;i++) {
    const t=i/rate;
    const envelope=loop?1:Math.min(1,t/.003)*Math.min(1,(seconds-t)/.05);
    data[i]=fn(t,low[i],high[i])*envelope;
    peak=Math.max(peak,Math.abs(data[i]));
  }
  const b=Buffer.alloc(44+n*2);
  b.write('RIFF');b.writeUInt32LE(b.length-8,4);b.write('WAVEfmt ',8);
  b.writeUInt32LE(16,16);b.writeUInt16LE(1,20);b.writeUInt16LE(1,22);
  b.writeUInt32LE(rate,24);b.writeUInt32LE(rate*2,28);b.writeUInt16LE(2,32);b.writeUInt16LE(16,34);
  b.write('data',36);b.writeUInt32LE(n*2,40);
  for(let i=0;i<n;i++) {
    const value=data[i]/peak*.7;
    energy+=value*value;
    b.writeInt16LE(Math.round(value*32767),44+i*2);
  }
  fs.writeFileSync(path.join(out,name+'.wav'),b);
  console.log(name, seconds+'s', 'RMS',Math.sqrt(energy/n).toFixed(3),'peak 0.700');
}
const sin=(f,t)=>Math.sin(2*Math.PI*f*t);
write('engine_loop',4,(t,l,h)=>(sin(56,t)*.7+sin(112,t)*.35+sin(168,t)*.12+sin(448,t)*.05)*(1+.17*sin(14,t))+l*.5+h*.07,true);
write('wind_loop',4,(t,l,h)=>(l*1.5+h*.18)*(1+.15*sin(.5,t)),true);
write('runner_loop',4,(t,l,h)=>(l*.8+h*.2)*(1+.3*sin(9,t))+sin(43,t)*.07,true);
write('mechanism_loop',2,(t,l,h)=>(sin(96,t)*.24+sin(288,t)*.08+h*.13)*(1+.22*sin(18,t)),true);
write('latch',.32,(t,l,h)=>h*Math.exp(-t*35)+sin(145,t)*.35*Math.exp(-t*22)+sin(760,t)*.1*Math.exp(-t*25));
write('touchdown',1.2,(t,l,h)=>sin(47,t)*Math.exp(-t*8)+l*2*Math.exp(-t*5)+h*.2*Math.exp(-t*14));
write('bomb_burst',1.7,(t,l,h)=>l*3*Math.exp(-t*3.5)+h*.45*Math.exp(-t*9)+sin(38,t)*.3*Math.exp(-t*5));
write('present_pop',.6,(t,l,h)=>h*Math.exp(-t*18)+sin(880,t)*.12*Math.exp(-t*9)+sin(1320,t)*.08*Math.exp(-t*10));
