import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
const DIR=path.dirname(fileURLToPath(import.meta.url)), REPO=path.resolve(DIR,'../..');
const STATE=path.join(DIR,'generated-state.json');
const files=['Assets/blockbench/driver/driver_01.bbmodel','Assets/blockbench/driver/driver_01_skin.png','Assets/blockbench/driver/driver_01_skin_night.png','Assets/export/glb/driver_01.glb'];
const hash=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
export function assertGeneratedUnchanged(){
  if(!fs.existsSync(STATE))throw Error('생성 기준 해시가 없습니다. 기존 모델을 덮어쓰지 않습니다.');
  const state=JSON.parse(fs.readFileSync(STATE,'utf8'));
  for(const file of files){const absolute=path.join(REPO,file);if(fs.existsSync(absolute)&&hash(absolute)!==state.files[file])throw Error('수작업 수정 가능성이 있는 파일입니다. 먼저 별도 보존하고 검토하세요: '+file);}
}
export function recordGeneratedState(){
  const state={note:'생성 도구의 자동 덮어쓰기 보호 기준. 수작업 수정본이 있으면 도구가 중단한다.',files:Object.fromEntries(files.filter(file=>fs.existsSync(path.join(REPO,file))).map(file=>[file,hash(path.join(REPO,file))]))};
  fs.writeFileSync(STATE,JSON.stringify(state,null,2)+'\n');
}
