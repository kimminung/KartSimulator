// humanoid 관절 구성을 참고하되 모델·UV·텍스처·키프레임은 이 작업에서 새로 만든다.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {createRequire} from 'node:module';
import {fileURLToPath} from 'node:url';
import {refine} from './refine-mesh.mjs';
import {assertGeneratedUnchanged,recordGeneratedState} from './generated-state.mjs';
assertGeneratedUnchanged();
const require=createRequire(import.meta.url);
let sharp;try{sharp=require('sharp');}catch{sharp=require('C:/Users/minsi/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');}
const DIR=path.dirname(fileURLToPath(import.meta.url)),REPO=path.resolve(DIR,'../..');
const OUT=path.join(REPO,'Assets/blockbench/driver');fs.mkdirSync(OUT,{recursive:true});
const uuid=s=>{const h=crypto.createHash('sha256').update('pinch-rover-driver-01/'+s).digest('hex');return `${h.slice(0,8)}-${h.slice(8,12)}-4${h.slice(13,16)}-a${h.slice(17,20)}-${h.slice(20,32)}`;};
const palette={navy:'#223A60',dark:'#0D1729',black:'#000918',white:'#F2F9FF',cyan:'#00F6F9',sky:'#1DB8E6',gold:'#FEDA34',silver:'#A5A6AB'};
const pixels=Buffer.alloc(128*128*4);const tiles={};
const rgb=s=>s.match(/[0-9a-f]{2}/gi).map(s=>parseInt(s,16));
function tile(name,paint){const n=Object.keys(tiles).length,x=n%8*16,y=Math.floor(n/8)*16;tiles[name]=[x+.01,y+.01,x+15.99,y+15.99];for(let v=0;v<16;v++)for(let u=0;u<16;u++){const c=paint(u,v);pixels.set([...rgb(c),255],((y+v)*128+x+u)*4);}}
for(const [name,c]of Object.entries(palette))tile(name,()=>c);
tile('suit',(x,y)=>x<2||x>13?palette.navy:y<3?palette.white:y===3?palette.sky:palette.white);
tile('chest',(x,y)=>x<3||x>12?palette.navy:y<2?palette.sky:y>12?palette.navy:((x===7||x===8)&&y>2)?palette.dark:palette.white);
tile('back',(x,y)=>y<3?palette.white:y===3?palette.sky:x>4&&x<11&&y>5&&y<11?palette.dark:palette.navy);
tile('boot',(x,y)=>y>12?palette.black:y>9?palette.sky:((x===3||x===12)&&y>3)?palette.silver:palette.dark);
tile('visor',(x,y)=>y<2?palette.sky:(x<5&&y<6)?palette.cyan:(x<7&&y===6)?palette.sky:palette.black);
tile('helmet',(x,y)=>x>5&&x<10?palette.sky:y>12?palette.navy:palette.white);
tile('cloth',(x,y)=>(x+y)%13===0?palette.navy:palette.dark);
const zero=['111','101','101','101','111'],one=['010','110','010','010','111'];
tile('badge',(x,y)=>{if(y>=5&&y<10){if(x>=3&&x<6&&zero[y-5][x-3]==='1')return palette.white;if(x>=9&&x<12&&one[y-5][x-9]==='1')return palette.white;}return palette.navy;});
const png=await sharp(pixels,{raw:{width:128,height:128,channels:4}}).png().toBuffer();fs.writeFileSync(path.join(OUT,'driver_01_skin.png'),png);await sharp(png).resize(768,768,{kernel:'nearest'}).png().toFile(path.join(DIR,'skin-preview.png'));
const bones=[],cubes=[];
function bone(name,parent,origin){bones.push({name,parent,origin,uuid:uuid(name),rotation:[0,0,0],export:true,visibility:true,autouv:0,isOpen:true});}
bone('root',null,[0,0,0]);bone('hip','root',[0,11.8,0]);bone('body','hip',[0,13,0]);bone('neck','body',[0,20.8,0]);bone('head','neck',[0,22,0]);
for(const [s,x]of [['l',5.1],['r',-5.1]]){bone('arm_'+s,'body',[x,19.6,0]);bone('forearm_'+s,'arm_'+s,[x,14.8,0]);bone('hand_'+s,'forearm_'+s,[x,10,0]);bone('thigh_'+s,'hip',[x>0?2.05:-2.05,11.8,0]);bone('shin_'+s,'thigh_'+s,[x>0?2.05:-2.05,6.5,0]);bone('foot_'+s,'shin_'+s,[x>0?2.05:-2.05,2,0]);}
function cube(name,group,from,to,color,front=color,back=color){const faces={};for(const side of ['north','south','east','west','up','down'])faces[side]={uv:tiles[side==='north'?front:side==='south'?back:color],texture:0};cubes.push({name,type:'cube',uuid:uuid('cube/'+name),from,to,origin:[0,0,0],rotation:[0,0,0],faces,box_uv:false,autouv:0,color:0,export:true,visibility:true,group});}
cube('pelvis','hip',[-3.5,11,-2.15],[3.5,13.7,2.15],'navy');cube('waist_belt','hip',[-3.65,13,-2.28],[3.65,13.8,2.28],'dark');cube('belt_buckle','hip',[-.7,13.1,-2.5],[.7,13.7,-2.28],'gold');
cube('suit_torso','body',[-3.8,13.8,-2.2],[3.8,20.5,2.2],'suit','chest','back');cube('shoulder_yoke','body',[-4.1,19.4,-2.32],[4.1,20.7,2.32],'white');
cube('race_number_01','body',[-1.2,16,-2.45],[1.2,18.4,-2.2],'navy','badge');cube('chest_seam_left','body',[-3.05,14.3,-2.34],[-2.48,19.4,-2.2],'sky');cube('chest_seam_right','body',[2.48,14.3,-2.34],[3.05,19.4,-2.2],'sky');
cube('neck_seal','neck',[-1.8,20.6,-1.7],[1.8,22.2,1.7],'dark');
cube('helmet_main','head',[-4.65,23,-3.8],[4.65,29.4,3.8],'white','white','helmet');cube('helmet_crown','head',[-3.85,29.4,-3.05],[3.85,30.3,3.05],'white');
cube('helmet_chin','head',[-3.85,22,-3.8],[3.85,23.4,3.3],'navy');cube('visor_frame','head',[-4.3,24.15,-4.15],[4.3,27.65,-3.8],'dark');cube('visor_glass','head',[-3.8,24.6,-4.35],[3.8,27.25,-4.15],'black','visor');
cube('helmet_brow','head',[-4.5,27.65,-4.25],[4.5,28.35,-3.75],'white');cube('helmet_top_stripe','head',[-.9,30.3,-2.8],[.9,30.48,2.8],'sky');
cube('chin_vent','head',[-1.35,22.45,-3.95],[1.35,23.05,-3.8],'silver');
for(const [s,x]of [['l',5.1],['r',-5.1]]){
 const sign=x>0?1:-1;const ax=(a,b)=>[Math.min(x+sign*a,x+sign*b),Math.max(x+sign*a,x+sign*b)];const c=(name,group,a,b,y0,y1,z0,z1,col,front=col)=>{const [x0,x1]=ax(a,b);cube(name+'_'+s,group+'_'+s,[x0,y0,z0],[x1,y1,z1],col,front);};
 c('upper_sleeve','arm',-1.05,1.05,14.7,19.6,-1.45,1.45,'white');c('shoulder_cap','arm',-1.3,1.3,18.2,20.1,-1.65,1.65,'navy');c('shoulder_stripe','arm',1.3,1.45,18.6,19.5,-1.3,1.3,'sky');
 c('elbow_joint','forearm',-.9,.9,14.2,15.4,-1.25,1.25,'dark');c('forearm_sleeve','forearm',-1.03,1.03,10.6,14.5,-1.4,1.4,'suit');c('cuff','forearm',-1.13,1.13,10.3,11.2,-1.5,1.5,'sky');
 c('glove','hand',-1.15,1.15,9.05,10.65,-1.6,1.6,'dark');c('glove_knuckles','hand',-.88,.88,9.45,10.25,-1.78,-1.6,'white');c('glove_thumb','hand',-1.65,-1.15,9.35,10.15,-.9,.65,'navy');
 const lx=sign*2.05;cube('thigh_'+s,'thigh_'+s,[lx-1.6,6.45,-1.65],[lx+1.6,11.85,1.65],'navy');cube('thigh_stripe_'+s,'thigh_'+s,[lx-1.42,7.4,-1.82],[lx-.72,11.1,-1.65],'sky');
 cube('knee_joint_'+s,'shin_'+s,[lx-1.38,5.8,-1.45],[lx+1.38,7.05,1.45],'dark');cube('shin_suit_'+s,'shin_'+s,[lx-1.5,2.1,-1.55],[lx+1.5,6.2,1.55],'cloth');cube('knee_pad_'+s,'shin_'+s,[lx-1.3,5.7,-1.88],[lx+1.3,6.9,-1.55],'white');
 cube('boot_'+s,'foot_'+s,[lx-1.7,.2,-2.9],[lx+1.7,2.65,1.65],'boot');cube('boot_sole_'+s,'foot_'+s,[lx-1.78,0,-3.05],[lx+1.78,.45,1.75],'black');cube('boot_toe_'+s,'foot_'+s,[lx-1.65,.45,-3.15],[lx+1.65,1.4,-2.9],'white');
 const ex=sign*4.65;cube('helmet_ear_'+s,'head',[Math.min(ex,ex+sign*.65),24,-2.1],[Math.max(ex,ex+sign*.65),26.8,1.7],'navy');cube('helmet_ear_insert_'+s,'head',[Math.min(ex+sign*.65,ex+sign*.8),24.7,-1.3],[Math.max(ex+sign*.65,ex+sign*.8),26.05,.8],'sky');
}
const outliner=bones.filter(b=>!b.parent).map(b=>node(b));function node(b){return {uuid:b.uuid,children:[...bones.filter(c=>c.parent===b.name).map(node),...cubes.filter(c=>c.group===b.name).map(c=>c.uuid)]};}
const model={meta:{format_version:'5.0',model_format:'free',box_uv:false},name:'driver_01',model_identifier:'driver_01',resolution:{width:128,height:128},elements:cubes.map(({group,...c})=>c),groups:bones.map(({parent,...b})=>b),outliner,textures:[{name:'driver_01_skin.png',id:'0',uuid:uuid('skin'),width:128,height:128,uv_width:128,uv_height:128,source:'data:image/png;base64,'+png.toString('base64'),mode:'bitmap',render_mode:'default',visible:true}],animations:[]};
const clips=[];const deg=Math.PI/180;
const rotateX=([x,y,z],a)=>[x,y*Math.cos(a*deg)-z*Math.sin(a*deg),y*Math.sin(a*deg)+z*Math.cos(a*deg)];
function basePose(){return Object.fromEntries(bones.map(b=>[b.name,{rotation:[0,0,0]}]));}
function seated(steer=0){
 const p=basePose();p.root.position=[0,-.35,2];p.body.rotation=[-10,0,0];p.head.rotation=[10,0,0];
 for(const s of ['l','r']){
  p['thigh_'+s].rotation=[90,0,0];p['shin_'+s].rotation=[2,0,0];p['foot_'+s].rotation=[-5,0,0];
  const x=s==='l'?5.1:-5.1,a=steer*deg,cx=-.11153,cy=18.91042;
  const target=[cx+(x-cx)*Math.cos(a)-(19.4-cy)*Math.sin(a),cy+(x-cx)*Math.sin(a)+(19.4-cy)*Math.cos(a),-7.98];
  const shoulder=rotateX([x,6.6,0],-10).map((v,i)=>v+[0,12.65,2][i]);
  const local=rotateX(target.map((v,i)=>v-shoulder[i]),10),[dx,dy,dz]=local,L=4.8;
  const distance=Math.hypot(dx,dy,dz),bend=Math.acos(Math.max(-1,Math.min(1,(distance*distance-2*L*L)/(2*L*L))))/deg;
  const direction=Math.atan2(Math.hypot(dx,dz),-dy)/deg,yaw=Math.atan2(-dx,-dz)/deg;
  p['arm_'+s].rotation=[direction-bend/2,yaw,0];p['forearm_'+s].rotation=[bend,0,0];p['hand_'+s].rotation=[100-(direction+bend/2),0,0];
 }
 return p;
}
function clip(name,length,loop,pose,fps=20){const channels={};for(const b of bones)channels[b.name]=[];for(let frame=0;frame<=Math.round(length*fps);frame++){const t=frame/fps,p=pose(t/length,t);for(const b of bones)channels[b.name].push({time:Number(t.toFixed(6)),...p[b.name]});}clips.push({name,animation_length:length,loop,bones:channels});}
clip('idle',2.4,true,(u)=>{const p=basePose();p.body.rotation=[0,0,Math.sin(u*2*Math.PI)*.65];p.head.rotation=[0,Math.sin(u*2*Math.PI)*2,0];for(const s of ['l','r'])p['arm_'+s].rotation=[0,0,s==='l'?-5:5];return p;});
function locomotion(u,run){const p=basePose(),a=u*2*Math.PI,amp=run?43:26;p.body.rotation=[run?-10:-3,0,Math.sin(a)*1.4];p.head.rotation=[run?10:3,0,0];p.root.position=[0,Math.abs(Math.sin(a))* (run?1.1:.28),0];for(const [s,phase]of [['l',0],['r',Math.PI]]){const q=a+phase;p['thigh_'+s].rotation=[Math.cos(q)*amp,0,0];p['shin_'+s].rotation=[-(run?12:3)-Math.max(0,-Math.sin(q))*(run?70:38),0,0];p['foot_'+s].rotation=[Math.max(-20,Math.min(20,-p['thigh_'+s].rotation[0]-p['shin_'+s].rotation[0])),0,0];p['arm_'+s].rotation=[-Math.cos(q)*(run?30:18),0,s==='l'?-4:4];p['forearm_'+s].rotation=[run?72:12,0,0];}return p;}
clip('walk',1.1,true,u=>locomotion(u,false));clip('run',.65,true,u=>locomotion(u,true));
function floor(w=1){const p=basePose();const thigh=98*w,knee=-12.5*w,foot=-5*w;const a=(thigh+knee+foot)*deg;const height=5.3*Math.cos(thigh*deg)+4.5*Math.cos((thigh+knee)*deg)+2*Math.cos(a)+1.82*Math.sin(a)-11.8;p.root.position=[0,Math.max(-10,height),0];p.body.rotation=[-6*w,0,0];p.head.rotation=[6*w,0,0];for(const s of ['l','r']){p['thigh_'+s].rotation=[thigh,0,0];p['shin_'+s].rotation=[knee,0,0];p['foot_'+s].rotation=[foot,0,0];p['arm_'+s].rotation=[35*w,0,(s==='l'?-8:8)*w];p['forearm_'+s].rotation=[15*w,0,0];}return p;}
clip('floor_sit',2,true,()=>floor());clip('sit_down',.85,false,u=>floor(u*u*(3-2*u)));
clip('kart_idle',2,true,()=>seated());clip('kart_steer',3,true,u=>seated(12*Math.sin(u*2*Math.PI)));
const refined=await refine(model);
// 실제 발바닥 정점으로 접지를 조정한다. 달리기에는 짧은 공중 구간을 둔다.
for(const clip of clips.filter(c=>c.name==='walk'||c.name==='run')){
 const keys=clip.bones.root;
 for(let i=0;i<keys.length;i++){
  let minimum=Infinity;
  for(const s of ['l','r']){
   const t=clip.bones['thigh_'+s][i].rotation[0]*deg,k=clip.bones['shin_'+s][i].rotation[0]*deg,f=clip.bones['foot_'+s][i].rotation[0]*deg;
   const ankle=11.8-5.3*Math.cos(t)-4.5*Math.cos(t+k);
   for(const mesh of model.elements.filter(m=>m.name==='boot_'+s||m.name==='boot_cuff_'+s||m.name==='boot_sole_'+s))for(const p of Object.values(mesh.vertices))minimum=Math.min(minimum,ankle+(p[1]-2)*Math.cos(t+k+f)-p[2]*Math.sin(t+k+f));
  }
  const flight=clip.name==='run'?Math.max(0,Math.sin(keys[i].time/clip.animation_length*4*Math.PI))*.65:0;
  keys[i].position[1]=-minimum+flight;
 }
}
fs.writeFileSync(path.join(OUT,'driver_01_skin.png'),refined.png);
fs.writeFileSync(path.join(OUT,'driver_01_skin_night.png'),refined.dark);
await sharp(refined.png).resize(refined.width*3,refined.height*3,{kernel:'nearest'}).png().toFile(path.join(DIR,'skin-preview.png'));
fs.writeFileSync(path.join(OUT,'driver_01.bbmodel'),JSON.stringify(model,null,2)+'\n');
fs.writeFileSync(path.join(DIR,'animation-spec.json'),JSON.stringify(clips,null,2)+'\n');
const RP='C:/Users/minsi/AppData/Roaming/Minecraft Bedrock/Users/Shared/games/com.mojang/development_resource_packs/resource_pack';
const refs=['models/entity/humanoid.custom.geo.json','animations/humanoid.animation.json'];
const reference={source:RP,readOnly:true,files:refs.map(p=>({path:p,sha256:crypto.createHash('sha256').update(fs.readFileSync(path.join(RP,p))).digest('hex')})),basis:'root/waist/body/head/leftArm/rightArm/leftLeg/rightLeg 계층과 보행·착석의 역할을 참고. 원본 큐브·UV·스킨·Molang 애니메이션은 복사하지 않음.',newDesign:'헬멧과 바이저, 짧은 몸통, 분리된 팔꿈치·무릎·손목·발목, 크림색/남색 레이싱 수트와 새 128×128 UV 아틀라스',units:'16 model units = 1 metre; Y up; forward -Z',gospelPose:{rootPosition:[0,-1.25,2],hipWorld:[0,10.55,2],seatBottomY:9.75,seatSurfaceY:9.705,steeringGripTargets:[[5.1,19.4,-7.98],[-5.1,19.4,-7.98]],note:'gospel 원본 geometry 기준 로컬 검토 배치. 다른 카트 좌석은 후속 개별 피팅.'},bones:bones.map(b=>({name:b.name,parent:b.parent,pivot:b.origin})),cubes:cubes.length,clips:clips.map(c=>({name:c.name,seconds:c.animation_length,loop:c.loop}))};
reference.cubes=0;reference.meshes=refined.meshes;reference.faces=refined.faces;reference.texture={width:refined.width,height:refined.height,layout:'면별 독립 UV, 1 texel gutter, 위치 기준 채색',variants:['cream','night']};reference.guidance={repository:'https://github.com/iMasterProX/mcbemodelingmasterAI',commit:'486c7f835ebd26a3c47cc46d96db1675f315c895',applied:['경사진 연결면으로 계단형 헬멧 제거','단일 폐쇄 메시로 겹치는 턱 면 제거','면별 독립 UV와 패딩','좌표 기준으로 바이저·수트 선을 연속 채색','실제 관절 피벗과 모든 포즈 렌더','가스펠 좌석·핸들 접촉 확인']};
reference.texture.layout='면별 독립 UV, 1 texel gutter, 위치 기준 채색';
reference.newDesign='닫힌 면과 경사진 모서리의 복셀 레이서. 크림색/남색 수트, 새 512×256 픽셀 채색, 원본 스티브 스킨 없음.';
reference.gospelPose={rootPosition:[0,-.35,2],hipWorld:[0,11.45,2],seatBottomY:9.70,seatSurfaceY:9.705,steeringGripTargets:[[5.1,19.4,-7.98],[-5.1,19.4,-7.98]],ankleRotationDegrees:-5,note:'기존 rideable의 발 기준 좌표와 신규 hip 좌표를 구분. 가스펠 로컬 피팅 검토본.'};
reference.texturingSources=['https://blockbench.net/wiki/guides/minecraft-style-guide/','https://learn.microsoft.com/en-us/minecraft/creator/documents/entitymodelingandanimation?view=minecraft-bedrock-stable'];
fs.writeFileSync(path.join(DIR,'model-spec.json'),JSON.stringify(reference,null,2)+'\n');
recordGeneratedState();
console.log(JSON.stringify({meshes:refined.meshes,faces:refined.faces,bones:bones.length,texture:[refined.width,refined.height],clips:clips.map(c=>c.name),output:OUT}));
