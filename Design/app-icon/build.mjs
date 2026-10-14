// 가스펠 bbmodel 원본을 읽어 앱 아이콘을 렌더링한다. 원본 파일은 수정하지 않는다.
// 실행: node Design/app-icon/build.mjs
// Node.js + sharp. macOS에서는 npm의 sharp, 이 PC에서는 C: 번들 sharp를 쓴다.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
const require = createRequire(import.meta.url);
let sharp;
try { sharp = require('sharp'); }
catch { sharp = require('C:/Users/minsi/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp'); }
const DIR = path.dirname(fileURLToPath(import.meta.url));
const config = JSON.parse(fs.readFileSync(path.join(DIR, 'composition.json'), 'utf8'));
const sourcePath = path.join(DIR, 'source/gospel.bbmodel');
const model = JSON.parse(fs.readFileSync(sourcePath, 'utf8'));
const N = config.size, SS = config.supersampling, W = N * SS;
const radians = n => n * Math.PI / 180;
const theta = radians(config.cameraElevationDegrees);
const sin = Math.sin(theta), cos = Math.cos(theta);
const dot = (a,b) => a.reduce((n,v,i) => n + v*b[i], 0);
const subtract = (a,b) => a.map((v,i) => v-b[i]);
const normalize = a => a.map(v => v/Math.hypot(...a));
// bbmodel 큐브는 Blockbench의 우수 좌표계와 ZYX 회전 순서를 쓴다.
function rotate(p, r = [0,0,0], o = [0,0,0]) {
  let [x,y,z] = subtract(p,o);
  const [a,b,c] = r.map(radians);
  [y,z] = [y*Math.cos(a)-z*Math.sin(a), y*Math.sin(a)+z*Math.cos(a)];
  [x,z] = [x*Math.cos(b)+z*Math.sin(b), -x*Math.sin(b)+z*Math.cos(b)];
  [x,y] = [x*Math.cos(c)-y*Math.sin(c), x*Math.sin(c)+y*Math.cos(c)];
  return [x+o[0],y+o[1],z+o[2]];
}
const groups = new Map(model.groups.map(g => [g.uuid,g]));
const chains = new Map();
function walk(nodes, chain = []) {
  for (const node of nodes) {
    if (typeof node === 'string') { chains.set(node,chain); continue; }
    const group = groups.get(node.uuid) || node;
    walk(node.children || [], [...chain,group]);
  }
}
walk(model.outliner);
const cubes = model.elements.filter(e => e.type === 'cube' && e.visibility !== false && e.export !== false &&
  !(chains.get(e.uuid)||[]).some(g => g.visibility === false || /anchor|vfx|particle/i.test(g.name)));
const selected = model.textures.find(t => t.name === config.texture);
if (!selected?.source?.startsWith('data:image/png;base64,')) throw new Error('모델 내장 텍스처가 없습니다.');
const textureBytes = Buffer.from(selected.source.split(',')[1], 'base64');
fs.writeFileSync(path.join(DIR,'source',config.texture),textureBytes);
const {data:tex,info:texInfo} = await sharp(textureBytes).ensureAlpha().raw().toBuffer({resolveWithObject:true});
const polygons = [];
for (const cube of cubes) {
  const chain = chains.get(cube.uuid) || [];
  const inflate = cube.inflate || 0;
  const [x0,y0,z0] = cube.from.map(v => v-inflate);
  const [x1,y1,z1] = cube.to.map(v => v+inflate);
  const faces = {
    north: [[x1,y1,z0],[x0,y1,z0],[x0,y0,z0],[x1,y0,z0]],
    south: [[x0,y1,z1],[x1,y1,z1],[x1,y0,z1],[x0,y0,z1]],
    east: [[x1,y1,z1],[x1,y1,z0],[x1,y0,z0],[x1,y0,z1]],
    west: [[x0,y1,z0],[x0,y1,z1],[x0,y0,z1],[x0,y0,z0]],
    up: [[x0,y1,z0],[x1,y1,z0],[x1,y1,z1],[x0,y1,z1]],
    down: [[x0,y0,z1],[x1,y0,z1],[x1,y0,z0],[x0,y0,z0]]
  };
  function transform(p) {
    p = rotate(p,cube.rotation,cube.origin);
    for (const g of chain.toReversed()) p = rotate(p,g.rotation,g.origin);
    return p;
  }
  const center = transform(cube.from.map((v,i) => (v+cube.to[i])/2));
  const groupNames = chain.map(g => g.name);
  const layer = groupNames.includes('A') || groupNames.includes('C') ||
    (groupNames.includes('body') && !groupNames.includes('steering_wheel') && center[2] < config.frontSplitZ) ? 2 : 1;
  for (const [name,local] of Object.entries(faces)) {
    const face = cube.faces[name];
    if (!face || face.texture === null) continue;
    const points = local.map(transform);
    const outward = {north:[0,0,-1],south:[0,0,1],east:[1,0,0],west:[-1,0,0],up:[0,1,0],down:[0,-1,0]}[name];
    const origin = cube.origin || [0,0,0];
    const normal = normalize(subtract(transform(origin.map((v,i)=>v+outward[i])),transform(origin)));
    if (!normal.every(Number.isFinite)) continue;
    const [u0,v0,u1,v1] = face.uv;
    let uv = [[u0,v0],[u1,v0],[u1,v1],[u0,v1]];
    const steps = (face.rotation || 0) / 90;
    for(let i=0;i<steps;i++) uv.unshift(uv.pop());
    const project = p => [-p[0],-p[1]*cos-p[2]*sin,-p[1]*sin+p[2]*cos];
    polygons.push({points:points.map(project),uv,normal,layer});
  }
}
const allPoints = polygons.flatMap(f => f.points);
const bounds = [0,1].map(i => [Math.min(...allPoints.map(p=>p[i])),Math.max(...allPoints.map(p=>p[i]))]);
const scale = Math.min(config.kartWidth/(bounds[0][1]-bounds[0][0]),config.kartHeight/(bounds[1][1]-bounds[1][0]));
const midX = (bounds[0][0]+bounds[0][1])/2, midY = (bounds[1][0]+bounds[1][1])/2;
for (const p of polygons) p.screen = p.points.map(([x,y,z])=>[(N/2+(x-midX)*scale)*SS,(config.kartCenterY+(y-midY)*scale)*SS,z]);
const lights = [normalize([-0.45,0.8,-0.5]),normalize([0.6,0.35,0.5])];
function render(layerFilter) {
  const pixels = Buffer.alloc(W*W*4);
  const depth = new Float32Array(W*W).fill(Infinity);
  const ownership = new Uint8Array(W*W);
  for(const face of polygons) {
    if (layerFilter && face.layer !== layerFilter) continue;
    // 양면을 깊이 버퍼로 처리. 투명 텍스처는 뒤의 표면을 가리지 않는다.
    const light = 0.72 + 0.30*Math.max(0,dot(face.normal,lights[0])) + 0.12*Math.max(0,dot(face.normal,lights[1]));
    for(const indices of [[0,1,2],[0,2,3]]) {
      const [a,b,c]=indices.map(i=>face.screen[i]);
      const [ta,tb,tc]=indices.map(i=>face.uv[i]);
      const denominator=(b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1]);
      if(Math.abs(denominator)<1e-7) continue;
      const left=Math.max(0,Math.floor(Math.min(a[0],b[0],c[0])));
      const right=Math.min(W-1,Math.ceil(Math.max(a[0],b[0],c[0])));
      const top=Math.max(0,Math.floor(Math.min(a[1],b[1],c[1])));
      const bottom=Math.min(W-1,Math.ceil(Math.max(a[1],b[1],c[1])));
      for(let y=top;y<=bottom;y++) for(let x=left;x<=right;x++) {
        const px=x+0.5,py=y+0.5;
        const aa=((b[1]-c[1])*(px-c[0])+(c[0]-b[0])*(py-c[1]))/denominator;
        const bb=((c[1]-a[1])*(px-c[0])+(a[0]-c[0])*(py-c[1]))/denominator;
        const cc=1-aa-bb;
        if(aa < -1e-7 || bb < -1e-7 || cc < -1e-7) continue;
        const d=aa*a[2]+bb*b[2]+cc*c[2],i=y*W+x;
        if(d>=depth[i]) continue;
        const u=aa*ta[0]+bb*tb[0]+cc*tc[0],v=aa*ta[1]+bb*tb[1]+cc*tc[1];
        const tx=Math.max(0,Math.min(texInfo.width-1,Math.floor(u*texInfo.width/model.resolution.width)));
        const ty=Math.max(0,Math.min(texInfo.height-1,Math.floor(v*texInfo.height/model.resolution.height)));
        const t=(ty*texInfo.width+tx)*4;
        // RetireX 원본의 발광 라인은 알파 8 마커를 쓴다. 이를 투명도 컷오프로 지우지 않는다.
        // 알파 0인 빈 영역만 제외하고 카트 표면은 불투명하게 렌더링한다.
        if(tex[t+3]===0) continue;
        // 내장 시안 라인은 원래 색을 유지해 작은 아이콘에서도 읽히게 한다.
        const emissive = tex[t+1] > tex[t]*1.6 && tex[t+2] > tex[t]*1.6 && tex[t+1] > 130;
        for(let k=0;k<3;k++) pixels[i*4+k]=Math.min(255,Math.round(tex[t+k]*(emissive?1:light)));
        pixels[i*4+3]=255;depth[i]=d;ownership[i]=face.layer;
      }
    }
  }
  return {pixels,depth,ownership};
}
const full = render();
const middle = render(1);
const front = Buffer.alloc(W*W*4);
for(let i=0;i<W*W;i++) if(full.ownership[i]===2) full.pixels.copy(front,i*4,i*4,i*4+4);
function png(raw) { return sharp(raw,{raw:{width:W,height:W,channels:4}}).resize(N,N,{kernel:'lanczos3'}).png().toBuffer(); }
const middlePng=await png(middle.pixels),frontPng=await png(front);
const scenePng=await png(full.pixels);
const bg=config.background;
const background=`<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024"><defs><linearGradient id="base" x2="0" y2="1"><stop stop-color="${bg.top}"/><stop offset="1" stop-color="${bg.bottom}"/></linearGradient><radialGradient id="halo" cx="50%" cy="42%" r="57%"><stop stop-color="${bg.halo}" stop-opacity=".35"/><stop offset=".7" stop-color="${bg.halo}" stop-opacity=".08"/><stop offset="1" stop-color="${bg.halo}" stop-opacity="0"/></radialGradient></defs><path fill="url(#base)" d="M0 0H1024V1024H0z"/><path fill="url(#halo)" d="M0 0H1024V1024H0z"/></svg>`;
fs.writeFileSync(path.join(DIR,'source/background.svg'),background+'\n');
const backPng=await sharp(Buffer.from(background)).removeAlpha().png().toBuffer();
const composite=await sharp(backPng).composite([{input:middlePng},{input:frontPng}]).removeAlpha().png().toBuffer();
const visionDir=path.join(DIR,'visionos/AppIcon.solidimagestack');
const iosDir=path.join(DIR,'ios/AppIcon.appiconset');
const masterDir=path.join(DIR,'master');
fs.mkdirSync(iosDir,{recursive:true});fs.mkdirSync(masterDir,{recursive:true});
const writeJson=(name,value)=>fs.writeFileSync(name,JSON.stringify(value,null,2)+'\n');
const info={author:'xcode',version:1};
for(const [name,file,data] of [['Back','back.png',backPng],['Middle','middle.png',middlePng],['Front','front.png',frontPng]]) {
  const layer=path.join(visionDir,`${name}.solidimagestacklayer`);
  const set=path.join(layer,'Content.imageset');fs.mkdirSync(set,{recursive:true});
  fs.writeFileSync(path.join(set,file),data);
  writeJson(path.join(layer,'Contents.json'),{info});
  writeJson(path.join(set,'Contents.json'),{images:[{filename:file,idiom:'vision',scale:'2x'}],info});
}
writeJson(path.join(visionDir,'Contents.json'),{layers:['Front','Middle','Back'].map(name=>({filename:`${name}.solidimagestacklayer`})),info});
fs.writeFileSync(path.join(iosDir,'icon_1024.png'),composite);
writeJson(path.join(iosDir,'Contents.json'),{images:[{filename:'icon_1024.png',idiom:'universal',platform:'ios',size:'1024x1024'}],info});
fs.writeFileSync(path.join(masterDir,'gospel-front.png'),scenePng);
fs.writeFileSync(path.join(masterDir,'composite.png'),composite);
await sharp(full.pixels,{raw:{width:W,height:W,channels:4}}).png().toFile(path.join(masterDir,'gospel-front-2048.png'));
const circle=Buffer.from('<svg width="1024" height="1024"><circle cx="512" cy="512" r="512" fill="white"/></svg>');
const rounded=Buffer.from('<svg width="1024" height="1024"><rect width="1024" height="1024" rx="225" fill="white"/></svg>');
const visionPreview=await sharp(composite).ensureAlpha().composite([{input:circle,blend:'dest-in'}]).png().toBuffer();
const iosPreview=await sharp(composite).ensureAlpha().composite([{input:rounded,blend:'dest-in'}]).png().toBuffer();
fs.writeFileSync(path.join(DIR,'preview-visionos.png'),visionPreview);
fs.writeFileSync(path.join(DIR,'preview-ios.png'),iosPreview);
const labelSvg=Buffer.from(`<svg width="1400" height="1040" xmlns="http://www.w3.org/2000/svg"><rect width="1400" height="1040" fill="#eef3f6"/><g fill="#142737" font-family="Malgun Gothic, Segoe UI, sans-serif"><text x="70" y="70" font-size="28" font-weight="600">핀치 로버 · 가스펠 앱 아이콘</text><text x="70" y="110" font-size="18">원본 bbmodel 정면 렌더 · 검정 차체와 시안 라인</text><text x="145" y="165" font-size="22">visionOS</text><text x="825" y="165" font-size="22">iOS / iPadOS</text><text x="70" y="820" font-size="20">128 · 64 · 32 px</text><text x="755" y="820" font-size="20">배경 · 뒤쪽 차체 · 앞쪽 차체</text><text x="70" y="1000" font-size="16">2026-10-14 · 디자인 전달본 · 마스크는 미리보기에만 적용</text></g></svg>`);
const panels=[];
panels.push({input:await sharp(visionPreview).resize(520,520).png().toBuffer(),left:90,top:205});
panels.push({input:await sharp(iosPreview).resize(520,520).png().toBuffer(),left:790,top:205});
for(const [i,n] of [128,64,32].entries()) panels.push({input:await sharp(visionPreview).resize(n,n).png().toBuffer(),left:75+i*170,top:860});
for(const [i,data] of [backPng,middlePng,frontPng].entries()) panels.push({input:await sharp(data).resize(140,140).png().toBuffer(),left:755+i*190,top:845});
await sharp(labelSvg).composite(panels).png().toFile(path.join(DIR,'preview.png'));
// 원형 마스크의 가장자리 및 이동 여유를 확인한다. 시스템 자체 시차 검증을 대신하지 않는다.
let visiblePixels=0,maxRadius=0,frontPixels=0,middlePixels=0,outsideMask=0;
for(let i=0;i<W*W;i++) if(full.pixels[i*4+3]) {
  const x=(i%W+0.5)/SS,y=(Math.floor(i/W)+0.5)/SS;
  const radius=Math.hypot(x-N/2,y-N/2);
  visiblePixels++;maxRadius=Math.max(maxRadius,radius);if(radius>N/2) outsideMask++;
  if(full.ownership[i]===2) frontPixels++;else middlePixels++;
}
const rawComposite=await sharp(composite).removeAlpha().raw().toBuffer();
const rawExpected=await sharp(backPng).composite([{input:scenePng}]).removeAlpha().raw().toBuffer();
let compositionAbsoluteError=0;
for(let i=0;i<rawComposite.length;i++) compositionAbsoluteError+=Math.abs(rawComposite[i]-rawExpected[i]);
const compositionMeanError=compositionAbsoluteError/rawComposite.length;
if(outsideMask || compositionMeanError>0.5) throw new Error('마스크 또는 레이어 합성 검증 실패');
const assetChecks=[];
for(const [name,bytes,alpha] of [['back',backPng,false],['middle',middlePng,true],['front',frontPng,true],['ios',composite,false]]) {
  const meta=await sharp(bytes).metadata();
  if(meta.width!==N||meta.height!==N||meta.hasAlpha!==alpha) throw new Error(`${name}: PNG 규격 오류`);
  assetChecks.push({name,width:meta.width,height:meta.height,channels:meta.channels,hasAlpha:meta.hasAlpha,space:meta.space});
}
let cyanPixels=0;
const rgbaScene=await sharp(scenePng).ensureAlpha().raw().toBuffer();
for(let i=0;i<rgbaScene.length;i+=4) if(rgbaScene[i+1]>rgbaScene[i]*1.6&&rgbaScene[i+2]>rgbaScene[i]*1.6&&rgbaScene[i+1]>130&&rgbaScene[i+3]>128) cyanPixels++;
if(cyanPixels<1000) throw new Error('시안 라인 렌더 확인 실패');
const report={sourceSha256:crypto.createHash('sha256').update(fs.readFileSync(sourcePath)).digest('hex'),
  texture:config.texture,cubes:cubes.length,faces:polygons.length,render:{size:N,supersampling:SS,cameraElevationDegrees:config.cameraElevationDegrees},
  layerVisiblePixels:{middle:middlePixels,front:frontPixels},mask:{outsidePixels:outsideMask,maxSubjectRadius:Number(maxRadius.toFixed(2)),radialMargin:Number((N/2-maxRadius).toFixed(2))},
  png:assetChecks,compositionMeanAbsoluteError:Number(compositionMeanError.toFixed(5)),cyanPixels,
  validation:'로컬 PNG·레이어·마스크 확인. Xcode·실기기 적용 전.'};
writeJson(path.join(DIR,'validation.json'),report);
function filesIn(dir) {
  return fs.readdirSync(dir,{withFileTypes:true}).flatMap(entry => {
    const absolute=path.join(dir,entry.name);
    return entry.isDirectory()?filesIn(absolute):entry.isFile()&&entry.name!=='manifest.sha256'?[absolute]:[];
  });
}
const manifest=filesIn(DIR).map(file=>{
  const relative=path.relative(DIR,file).split(path.sep).join('/');
  const hash=crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
  return {relative,line:`${hash}  ${relative}`};
}).sort((a,b)=>a.relative.localeCompare(b.relative,'en')).map(item=>item.line).join('\n')+'\n';
fs.writeFileSync(path.join(DIR,'manifest.sha256'),manifest);
console.log(JSON.stringify(report,null,2));
