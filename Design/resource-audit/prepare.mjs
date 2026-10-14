// 사용자 승인 리소스를 로컬로 준비한다. 원본·앱 코드는 수정하지 않는다.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {createRequire} from 'node:module';
import {fileURLToPath} from 'node:url';
const require=createRequire(import.meta.url);
let sharp;try{sharp=require('sharp');}catch{sharp=require('C:/Users/minsi/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');}
const DIR=path.dirname(fileURLToPath(import.meta.url));
const RP=process.argv[2]||'C:/Users/minsi/AppData/Roaming/Minecraft Bedrock/Users/Shared/games/com.mojang/development_resource_packs/RetireX_Online_RP';
const groups=[
  {id:'direction-signs',name:'방향 안내판',use:'서킷 벽과 코너 방향 안내',priority:'높음',paths:['textures/blocks/direction_arrow_left.png','textures/blocks/direction_arrow_right.png']},
  {id:'countdown-art',name:'3·2·1·GO 그림',use:'준비음과 맞춘 카운트다운 연출 대안',priority:'선택',paths:['textures/ui/rxo/banners/count_3.png','textures/ui/rxo/banners/count_2.png','textures/ui/rxo/banners/count_1.png','textures/ui/rxo/banners/go.png']},
  {id:'lap-banner',name:'일반 랩 2~99 및 FINAL LAP 그림',use:'중간 랩과 마지막 랩 진입 안내',priority:'중간',paths:[...Array.from({length:98},(_,i)=>`textures/ui/rxo/banners/lap_${i+2}.png`),'textures/ui/rxo/banners/final_lap.png']},
  {id:'progress-gauge',name:'가로 게이지 틀·채움',use:'랩 진행률·진행 막대의 외형 대안',priority:'선택',paths:['textures/ui/rxo_team_gauge_frame.png','textures/ui/rxo_team_gauge_fill.png']},
  {id:'track-pads',name:'부스트·점프 패드',use:'후속 기믹 또는 장식 검토. 현재 주행 규칙에 자동 추가하지 않음',priority:'후속',paths:['models/entity/boost_block.json','models/entity/jump_block.json','textures/blocks/boost_block.png','textures/blocks/jump_block.png']},
  {id:'ui-cues',name:'기록·랩·오류 효과음',use:'신기록·랩 통과·오류의 효과음 대안',priority:'중간',paths:['sounds/rxoeffect/cue_record.ogg','sounds/rxoeffect/cue_middle_lap.ogg','sounds/rxoeffect/cue_error.ogg']}
];
const files=[];
for(const group of groups)for(const relative of group.paths){
  if(/discovery4/i.test(relative))throw new Error('읽지 않는 모델');
  const source=path.join(RP,relative),destination=path.join(DIR,'candidates',relative);
  const bytes=fs.readFileSync(source);fs.mkdirSync(path.dirname(destination),{recursive:true});fs.writeFileSync(destination,bytes);
  let meta={};if(relative.endsWith('.png')){const m=await sharp(bytes).metadata();meta={width:m.width,height:m.height,hasAlpha:m.hasAlpha};}
  files.push({group:group.id,path:relative,size:bytes.length,sha256:crypto.createHash('sha256').update(bytes).digest('hex'),...meta,status:'2026-10-14 사용자 전 후보 승인'});
}
const previewPaths=['textures/blocks/direction_arrow_left.png','textures/blocks/direction_arrow_right.png','textures/ui/rxo/banners/count_3.png','textures/ui/rxo/banners/go.png','textures/ui/rxo/banners/final_lap.png','textures/ui/rxo_team_gauge_frame.png','textures/blocks/boost_block.png','textures/blocks/jump_block.png','textures/ui/rxo_team_gauge_fill.png'];
const labels=['왼쪽 방향 안내판','오른쪽 방향 안내판','카운트다운 그림 예시','GO 그림','마지막 랩 배너','가로 게이지 틀','부스트 패드 텍스처','점프 패드 텍스처','가로 게이지 채움'];
const svg=Buffer.from(`<svg width="1380" height="1100" xmlns="http://www.w3.org/2000/svg"><rect width="1380" height="1100" fill="#0D1729"/><g font-family="Malgun Gothic,Segoe UI,sans-serif" fill="#F2F9FF"><text x="34" y="50" font-size="25" font-weight="600">RetireX 추가 리소스 · 전 후보 사용자 승인</text><text x="34" y="86" font-size="17">일반 랩 2~99 추가 · 애니메이션 시트는 첫 프레임만 표시</text>${labels.map((s,i)=>`<text x="${34+(i%3)*455}" y="${132+Math.floor(i/3)*310}" font-size="18">${s}</text>`).join('')}<text x="34" y="1070" font-size="15">6묶음·114파일 승인. 랩 전체 이미지는 lap-preview.png에서 확인. 앱 연결은 테크 후속.</text></g></svg>`);
const panels=[];
for(const [i,relative]of previewPaths.entries()){
  let p=sharp(path.join(DIR,'candidates',relative));
  if(relative.includes('/blocks/'))p=p.extract({left:0,top:0,width:64,height:64});
  const data=await p.resize(390,230,{fit:'inside',kernel:'nearest'}).png().toBuffer();
  const m=await sharp(data).metadata();panels.push({input:data,left:34+(i%3)*455+Math.floor((390-m.width)/2),top:153+Math.floor(i/3)*310+Math.floor((230-m.height)/2)});
}
await sharp(svg).composite(panels).png().toFile(path.join(DIR,'preview.png'));
const report={sourceRP:RP,sourceVersion:JSON.parse(fs.readFileSync(path.join(RP,'manifest.json'),'utf8')).header.version,groups,files,
  lapBannerRule:{normalLapRange:[2,99],normalPattern:'lap_{lap}.png',finalLap:'final_lap.png',selection:'다음 랩이 총 랩 수이면 FINAL LAP, 그 외 2~99는 일반 랩 이미지. 완주에는 표시하지 않음.'},
  exclusions:[{path:'entity/gate_marker.json',reason:'geometry.pig와 textures/entity/pig/pig를 참조해 모장 바닐라 자산으로 제외.'}],status:'2026-10-14 전 후보 사용자 승인. 일반 랩 2~99 추가. 앱 연결은 테크 후속.'};
report.flipbooks=JSON.parse(fs.readFileSync(path.join(RP,'textures/flipbook_textures.json'),'utf8')).filter(item=>groups.some(group=>group.paths.includes(item.flipbook_texture+'.png')));
fs.writeFileSync(path.join(DIR,'inventory.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({groups:groups.length,files:files.length,sourceVersion:report.sourceVersion}));
const lapFiles=[...Array.from({length:98},(_,i)=>`lap_${i+2}.png`),'final_lap.png'];
const sheet=Buffer.from(`<svg width="1800" height="1230" xmlns="http://www.w3.org/2000/svg"><rect width="1800" height="1230" fill="#182538"/><g fill="#F2F9FF" font-family="Malgun Gothic,Segoe UI,sans-serif"><text x="25" y="38" font-size="24">일반 랩 2~99 · FINAL LAP · 사용자 승인</text>${lapFiles.map((p,i)=>`<text x="${20+i%9*198}" y="${74+Math.floor(i/9)*104}" font-size="14">${p}</text>`).join('')}</g></svg>`);
const lapPanels=[];for(const [i,file]of lapFiles.entries()){const bytes=await sharp(path.join(DIR,'candidates/textures/ui/rxo/banners',file)).resize(178,64,{fit:'inside',kernel:'nearest'}).png().toBuffer();const m=await sharp(bytes).metadata();lapPanels.push({input:bytes,left:20+i%9*198+Math.floor((178-m.width)/2),top:85+Math.floor(i/9)*104+Math.floor((64-m.height)/2)});}
await sharp(sheet).composite(lapPanels).png().toFile(path.join(DIR,'lap-preview.png'));
