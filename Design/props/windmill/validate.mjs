import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
const DIR=path.dirname(fileURLToPath(import.meta.url)),SRC=path.join(DIR,'source');
const RP=process.argv[2]||'C:/Users/minsi/AppData/Roaming/Minecraft Bedrock/Users/Shared/games/com.mojang/development_resource_packs/RetireX_Online_RP';
const mapping={
  'windmill.geo.json':'models/entity/windmill.geo.json',
  'windmill.animation.json':'animations/windmill.animation.json',
  'windmill.json':'entity/windmill.json',
  'windmill.render_controllers.json':'render_controllers/windmill.render_controllers.json',
  'windmill.png':'textures/entity/windmill/windmill.png',
  'windmill_small.png':'textures/entity/windmill/windmill_small.png'
};
const files=[];
for(const [name,original]of Object.entries(mapping)) {
  const bytes=fs.readFileSync(path.join(SRC,name)),source=fs.readFileSync(path.join(RP,original));
  if(!bytes.equals(source))throw new Error(`${name}: 원본과 바이트 불일치`);
  files.push({name,source:original,sha256:crypto.createHash('sha256').update(bytes).digest('hex'),byteIdentical:true});
}
const geometry=JSON.parse(fs.readFileSync(path.join(SRC,'windmill.geo.json'),'utf8'))['minecraft:geometry'][0];
const names=new Set(geometry.bones.map(b=>b.name));
for(const bone of geometry.bones)if(bone.parent&&!names.has(bone.parent))throw new Error(`없는 부모 본 ${bone.parent}`);
const animation=JSON.parse(fs.readFileSync(path.join(SRC,'windmill.animation.json'),'utf8')).animations['animation.rita.windmill.turn'];
for(const name of Object.keys(animation.bones))if(!names.has(name))throw new Error(`없는 애니메이션 본 ${name}`);
if(animation.bones.sails.rotation[2]!=='q.life_time * 36.0'||animation.bones.fantail.rotation[0]!=='q.life_time * -50.0')throw new Error('회전식이 예상과 다릅니다.');
const report={files,bones:geometry.bones.map(b=>({name:b.name,parent:b.parent,pivot:b.pivot,rotation:b.rotation,cubes:b.cubes?.length||0})),
  cubeCount:geometry.bones.reduce((n,b)=>n+(b.cubes?.length||0),0),
  animation:{loop:animation.loop,sailsDegreesPerSecond:36,sailsPeriodSeconds:10,fantailDegreesPerSecond:-50,fantailPeriodSeconds:7.2,combinedPeriodSeconds:180},
  appConverted:false,appAnimationVerified:false};
fs.writeFileSync(path.join(DIR,'validation.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({files:files.length,cubes:report.cubeCount,bones:report.bones.length,animation:report.animation,appConverted:false}));
