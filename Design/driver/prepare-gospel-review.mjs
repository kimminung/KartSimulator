import fs from 'node:fs';import path from 'node:path';import {fileURLToPath} from 'node:url';
const DIR=path.dirname(fileURLToPath(import.meta.url)),REPO=path.resolve(DIR,'../..');
const driver=JSON.parse(fs.readFileSync(path.join(REPO,'Assets/blockbench/driver/driver_01.bbmodel')));
const gospel=JSON.parse(fs.readFileSync(path.join(REPO,'Design/app-icon/source/gospel.bbmodel')));
const config=JSON.parse(fs.readFileSync(path.join(REPO,'Design/app-icon/composition.json')));
const selected=gospel.textures.find(t=>t.name===config.texture);
selected.id='1';
driver.name='driver_01_gospel_review';
driver.textures.push(selected);
driver.elements.push(...gospel.elements.filter(e=>e.type==='cube').map(e=>({...e,faces:Object.fromEntries(Object.entries(e.faces).map(([k,f])=>[k,{...f,texture:f.texture===null?null:1}]))})));
driver.groups.push(...gospel.groups.map(g=>({...g,name:'gospel_'+g.name})));
driver.outliner.push(...gospel.outliner);
// 검토용 카트의 같은 본 UUID에 핸들 회전을 연결한다.
for(const a of driver.animations){if(a.name==='animation.kart_steer'){
 const wheel=gospel.groups.find(g=>g.name==='steering_wheel');
 a.animators[wheel.uuid]={name:'gospel_steering_wheel',type:'bone',keyframes:Array.from({length:61},(_,i)=>({channel:'rotation',time:i*.05,data_points:[{x:0,y:0,z:12*Math.sin(i*.05/3*2*Math.PI)}],interpolation:'linear'}))};
}}
fs.writeFileSync(path.join(DIR,'driver_01_gospel_review.bbmodel'),JSON.stringify(driver,null,2)+'\n');
console.log(JSON.stringify({meshes:driver.elements.filter(e=>e.type==='mesh').length,cubes:driver.elements.filter(e=>e.type==='cube').length,texture:config.texture}));
