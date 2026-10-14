// 사용자 PSD에서 이미 내보낸 PNG 레이어를 바이트 동일하게 정리한다.
// 실행: node Design/hud/build.mjs
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {createRequire} from 'node:module';
import {fileURLToPath} from 'node:url';
const require=createRequire(import.meta.url);
let sharp;try{sharp=require('sharp');}catch{sharp=require('C:/Users/minsi/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');}
const DIR=path.dirname(fileURLToPath(import.meta.url)),SRC=path.join(DIR,'source');
const spec=JSON.parse(fs.readFileSync(path.join(DIR,'dial_spec.json'),'utf8'));
const {width:W,height:H}=spec.canvas;
const mappings={
  'hud_frame_back.png':'speedometer_background.png',
  'hud_frame_front.png':'speedometer_frame.png',
  'hud_frame_front_boost.png':'speedometer_frame_boost.png',
  'hud_boost_fill.png':'speedometer_gauge.png'
};
const pngChecks=[];
for(const [original,output]of Object.entries(mappings)) {
  const bytes=fs.readFileSync(path.join(SRC,original));
  const meta=await sharp(bytes).metadata();
  if(meta.width!==W||meta.height!==H||!meta.hasAlpha)throw new Error(`${original}: 캔버스 또는 알파 불일치`);
  fs.writeFileSync(path.join(DIR,output),bytes);
  pngChecks.push({original,output,width:meta.width,height:meta.height,hasAlpha:meta.hasAlpha,byteIdentical:true});
}
const fill=await sharp(path.join(DIR,'speedometer_gauge.png')).ensureAlpha().raw().toBuffer();
function maskedFill(ratio) {
  const pixels=Buffer.alloc(W*H*4);
  const start=spec.gauge.startDegrees,end=start+spec.gauge.sweepDegrees*Math.max(0,Math.min(1,ratio));
  if(ratio<=0)return pixels;
  for(let y=0;y<H;y++)for(let x=0;x<W;x++) {
    let degrees=Math.atan2(y+.5-spec.gauge.center[1],x+.5-spec.gauge.center[0])*180/Math.PI;
    while(degrees<start-1e-6)degrees+=360;
    if(degrees<start-1e-6||degrees>end+1e-6)continue;
    const i=(y*W+x)*4;fill.copy(pixels,i,i,i+4);
  }
  return pixels;
}
const base=path.join(DIR,'speedometer_background.png');
async function compose(speed,{number=false,forceBoost}={}) {
  const ratio=Math.max(0,Math.min(1,Math.abs(speed)/spec.gauge.maximumKmh));
  const boosted=forceBoost??(Math.abs(speed)>=spec.boost.defaultThresholdKmh);
  const frame=path.join(DIR,boosted?spec.boostFrame:'speedometer_frame.png');
  const layers=[{input:maskedFill(ratio),raw:{width:W,height:H,channels:4}},{input:frame}];
  if(number)layers.push({input:Buffer.from(`<svg width="103" height="79"><text x="51.5" y="50" text-anchor="middle" font-family="Segoe UI,sans-serif" font-size="22" font-weight="600" fill="#F2F9FF">${Math.round(speed)}</text></svg>`)});
  return sharp(base).composite(layers).png().toBuffer();
}
for(const [name,speed,boost]of [['empty-normal',0,false],['empty-boost',0,true],['full-normal',20,false],['full-boost',20,true]])fs.writeFileSync(path.join(DIR,`preview-${name}.png`),await compose(speed,{forceBoost:boost}));
const center=spec.gauge.center,start=spec.gauge.startDegrees,sweep=spec.gauge.sweepDegrees;
const point=a=>[center[0]+150*Math.cos(a*Math.PI/180),center[1]+150*Math.sin(a*Math.PI/180)];
const a=point(start),b=point(start+sweep);
fs.writeFileSync(path.join(DIR,'speedometer_gauge_mask.svg'),`<svg xmlns="http://www.w3.org/2000/svg" width="103" height="79" viewBox="0 0 103 79"><path fill="white" d="M${center.join(' ')} L${a.join(' ')} A150 150 0 1 1 ${b.join(' ')} Z"/></svg>\n`);
const samples=[0,7.2,12.96,14.4,18,20];
const sheet=Buffer.from(`<svg width="1320" height="950" xmlns="http://www.w3.org/2000/svg"><rect width="1320" height="950" fill="#0D1729"/><g fill="#F2F9FF" font-family="Malgun Gothic,Segoe UI,sans-serif"><text x="34" y="48" font-size="25" font-weight="600">핀치 로버 · 속도계 레이어 전달본</text><text x="34" y="82" font-size="17">PSD 원본 PNG 유지 · 0~20 km/h · 기본 부스트 전환 12.96 km/h</text>${['배경','일반 프레임','부스트 프레임','게이지'].map((s,i)=>`<text x="${34+i*318}" y="122" font-size="17">${s}</text>`).join('')}${samples.map((v,i)=>`<text x="${34+(i%3)*425}" y="${475+Math.floor(i/3)*235}" font-size="17">${v} km/h · ${Math.round(v/20*100)} %${v>=12.96?' · 부스트':''}</text>`).join('')}<text x="34" y="925" font-size="15">확대 미리보기 · 정수 숫자는 배치 예시 · 실제 앱에서는 시스템 고정폭 숫자 사용</text></g></svg>`);
const panels=[];
for(const [i,name]of ['speedometer_background.png','speedometer_frame.png','speedometer_frame_boost.png','speedometer_gauge.png'].entries())panels.push({input:await sharp(path.join(DIR,name)).resize(W*3,H*3,{kernel:'nearest'}).png().toBuffer(),left:34+i*318,top:145});
for(const [i,value]of samples.entries())panels.push({input:await sharp(await compose(value,{number:true})).resize(W*2,H*2,{kernel:'nearest'}).png().toBuffer(),left:34+(i%3)*425,top:485+Math.floor(i/3)*235});
await sharp(sheet).composite(panels).png().toFile(path.join(DIR,'preview.png'));
const report={sourcePsdSha256:crypto.createHash('sha256').update(fs.readFileSync(path.join(SRC,'speedometer.psd'))).digest('hex'),png:pngChecks,
  thresholdKmh:spec.boost.defaultThresholdKmh,samples:samples.map(speed=>({speedKmh:speed,ratio:speed/20,boost:speed>=12.96})),
  status:'레이어·합성·숫자 배치 미리보기 확인용. 앱 적용·실기기 확인 전.'};
const reference=process.argv[2]||'D:/RetireX/RetireX_Online_Addon/development_resource_packs/RetireX_Online_RP/textures/ui/rxo_hud_dial.png';
if(fs.existsSync(reference)) {
  const comparisons=[];
  for(const [name,index]of [['empty-normal',0],['empty-boost',51]]) {
    const actual=await sharp(path.join(DIR,`preview-${name}.png`)).ensureAlpha().raw().toBuffer();
    const expected=await sharp(reference).extract({left:index%11*W,top:Math.floor(index/11)*H,width:W,height:H}).ensureAlpha().raw().toBuffer();
    let differentBytes=0;for(let i=0;i<actual.length;i++)if(actual[i]!==expected[i])differentBytes++;
    if(differentBytes)throw new Error(`${name}: 원본 빈 프레임과 불일치`);
    comparisons.push({name,atlasIndex:index,differentBytes});
  }
  report.emptyFrameComparisons=comparisons;
}
fs.writeFileSync(path.join(DIR,'validation.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify(report,null,2));
