// Rebuild with node art/audio/build_quartermaster.cjs. Voice and timing are
// cut together so a changed line gets new phrasing and matching subtitles.
const fs = require("node:fs");
const path = require("node:path");
const output = path.resolve(__dirname, "../../assets/audio/quartermaster");
const rate = 24000;
const lines = {
  offer: "Here for a chat, or shall I show you what's for sale?",
  stock: "Have a look. What can I set aside for you?",
  welcome: "Come in, come in. That wind's got teeth tonight.",
  outfitter: "See that mitt? Eight vouchers. My sister stitched it from an old flight jacket.",
  chart: "Recognize the paper stars? Last winter's charts. That's my milk round over the till.",
  couch: "That couch came off a mail train. Took four of us to get it through the door.",
  cocoa: "If the kettle whistles while you're here, give me a shout. I can't hear it over the mail rail.",
  issued_mitt: "There's your mitt. Already broken in. Give it a throw!",
  issued_sling: "Sling's yours. Mind the buckle. It bites if you rush it.",
  issued_present: "There you go. Ribbon's tied tight for the flight.",
  hands_full: "Set something down first. I don't want you dropping this one.",
  owned: "Check the crew locker. I stamped that one out to you already.",
  short: "Little short today. Bring a few more vouchers and we'll square up.",
};

// Formants (Hz) for the open, closed, and rounded vowels of the clerk's patter.
const vowels = { a: [800, 1430, 2750], e: [535, 1910, 2810],
  i: [355, 2190, 2970], o: [510, 960, 2520], u: [350, 850, 2300] };
const gains = [1, .62, .23], bandwidths = [105, 155, 225];

function speak(text) {
  const pcm = [], cues = [], syllables = [];
  let sequence = 0, seed = 1947;
  const ms = () => Math.round(pcm.length * 1000 / rate);
  const rest = seconds => {
    for (let i = 0; i < Math.round(rate * seconds); i++) pcm.push(0);
  };
  function syllable(vowel, onset, seconds, pitch, landing) {
    const target = vowels[vowel];
    const rounded = /[bwmp]/.test(onset);
    const hiss = /[fhstck]/.test(onset) ? 0.17 : 0.035;
    let phase = 0, noiseBefore = 0;
    const count = Math.round(seconds * rate);
    for (let i = 0; i < count; i++) {
      const t = i / rate, u = i / count;
      const hz = pitch * (0.96 + 0.105 * Math.sin(Math.PI * u) + landing * u);
      phase = (phase + hz / rate) % 1;
      const pulseAge = phase / hz;
      const glide = Math.exp(-t * 67);
      let voiced = 0.15 * Math.sin(2 * Math.PI * phase);
      for (let j = 0; j < 3; j++) {
        const center = target[j] * (1 - glide * (rounded ? 0.28 : 0.11));
        voiced += gains[j] * Math.sin(2 * Math.PI * center * pulseAge)
          * Math.exp(-Math.PI * bandwidths[j] * pulseAge);
      }
      seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0;
      const noise = seed / 2147483648 - 1;
      const burst = hiss * (noise - noiseBefore) * Math.exp(-85 * t);
      noiseBefore = noise;
      const attack = Math.min(1, t / .011);
      const release = Math.min(1, (1 - u) * seconds / .030);
      pcm.push((voiced * (.94 - .18 * u) + burst) * attack * release);
    }
  }
  for (const match of text.matchAll(/[A-Za-z']+|[^A-Za-z']/g)) {
    const token = match[0];
    if (!/[A-Za-z]/.test(token)) {
      cues.push(ms());
      rest(/[.!?]/.test(token) ? .18 : token === "," ? .115 : .025);
      continue;
    }
    const word = token.toLowerCase();
    const stem = word.length > 3 ? word.replace(/([^aeiou])e$/, "$1") : word;
    const nuclei = Array.from(stem.matchAll(/[aeiouy]+/g));
    if (!nuclei.length) nuclei.push({ 0: "u", index: 0 });
    const start = ms();
    const after = text[match.index + word.length] || ".";
    for (let j = 0; j < nuclei.length; j++) {
      const nucleus = nuclei[j], vowel = nucleus[0][0].replace("y", "i");
      const accent = (sequence++ * 7 + word.charCodeAt(0)) % 11;
      const last = j === nuclei.length - 1 && /[.,!?]/.test(after);
      const pitch = 190 + accent * 4 + (j === 0 ? 9 : -5);
      const duration = .091 + accent * .003 + (last ? .058 : 0);
      syllables.push(ms());
      syllable(vowel, word[Math.max(0, nucleus.index - 1)], duration, pitch,
        last ? (after === "?" ? .23 : -.16) : -.035);
      syllables.push(ms());
      rest(.012);
    }
    const span = ms() - start;
    for (let j = 0; j < word.length; j++) cues.push(start + Math.round(span * j / word.length));
  }
  const amplitude = pcm.reduce((peak, sample) => Math.max(peak, Math.abs(sample)), 0);
  const wav = Buffer.alloc(44 + pcm.length * 2);
  wav.write("RIFF"); wav.writeUInt32LE(wav.length - 8, 4); wav.write("WAVEfmt ", 8);
  wav.writeUInt32LE(16, 16); wav.writeUInt16LE(1, 20); wav.writeUInt16LE(1, 22);
  wav.writeUInt32LE(rate, 24); wav.writeUInt32LE(rate * 2, 28);
  wav.writeUInt16LE(2, 32); wav.writeUInt16LE(16, 34);
  wav.write("data", 36); wav.writeUInt32LE(wav.length - 44, 40);
  pcm.forEach((v, i) => wav.writeInt16LE(Math.round(v / amplitude * 26000), 44 + i * 2));
  return { wav, cues, syllables };
}

fs.mkdirSync(output, { recursive: true });
const resources = ['[gd_resource type="Resource" format=3]', ''];
const entries = ['', '[resource]'];
for (const [id, text] of Object.entries(lines)) {
  const { wav, cues, syllables } = speak(text);
  fs.writeFileSync(path.join(output, id + ".wav"), wav);
  resources.push(`[ext_resource type="AudioStream" path="res://assets/audio/quartermaster/${id}.wav" id="${id}"]`);
  entries.push(`metadata/${id} = {"text": ${JSON.stringify(text)}, "voice": ExtResource("${id}"), "cues": PackedInt32Array(${cues.join(", ")}), "syllables": PackedInt32Array(${syllables.join(", ")})}`);
}
fs.writeFileSync(path.join(output, "lines.tres"), [...resources, ...entries, ""].join("\n"));
