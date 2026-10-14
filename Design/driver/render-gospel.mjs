import fs from 'node:fs';import path from 'node:path';import {fileURLToPath} from 'node:url';
import {connect,textResult,saveImage} from './mcp-client.mjs';
const DIR=path.dirname(fileURLToPath(import.meta.url));const c=await connect();
try{
 const check=JSON.parse(textResult(await c.call('risky_eval',{code:'({elements:Outliner.elements.length})'})));if(check.elements!==0)throw new Error('빈 검토 프로젝트에서만 동작');
 const modelPath=path.join(DIR,'driver_01_gospel_review.bbmodel').replaceAll('\\','/');
 await c.call('save_checkpoint',{name:'gospel seated driver review blank'});
 await c.call('risky_eval',{code:`(()=>{let bytes=requireNativeModule('fs').readFileSync('${modelPath}','utf8');Undo.initEdit({elements:[],outliner:true,textures:[],animations:[]});Codecs.project.parse(JSON.parse(bytes),'driver_01_gospel_review.bbmodel');Undo.finishEdit('Load separate gospel fit review');Canvas.updateAll();return Project.name;})()`});
 await c.call('set_mode',{mode_id:'animate'});
 await c.call('risky_eval',{code:'Animation.all.find(a=>a.name==="animation.kart_idle").select()'});
 await c.call('animation_timeline',{action:'set_time',time:0});
 await c.call('create_offscreen_view',{id:'gospel_review',width:1400,height:1100,copy_view:'none',antialias:true});
 const list=[['gospel_front',[52,40,-72],[0,14,-6],.46],['gospel_side',[75,29,-7],[0,14,-6],.46],['gospel_rear',[-50,40,65],[0,14,-4],.46],['gospel_grip',[30,28,-34],[0,17,-5],.85]];
 for(const [name,position,target,zoom]of list){saveImage(await c.call('set_camera_angle',{view:'gospel_review',position,target,projection:'orthographic',zoom,format:'png'}),path.join(DIR,'renders',name+'.png'));console.log(name);}
 await c.call('risky_eval',{code:'Animation.all.find(a=>a.name==="animation.kart_steer").select()'});
 const grip=[];
 for(const [name,time]of [['steer_left',.75],['steer_right',2.25]]){
  await c.call('animation_timeline',{action:'set_time',time});
  saveImage(await c.call('set_camera_angle',{view:'gospel_review',position:[30,28,-34],target:[0,17,-5],projection:'orthographic',zoom:.85,format:'png'}),path.join(DIR,'renders',name+'.png'));
  grip.push(JSON.parse(textResult(await c.call('risky_eval',{code:'Group.all.filter(g=>/^hand_/.test(g.name)).map(g=>({name:g.name,world:g.mesh.getWorldPosition(new THREE.Vector3()).toArray()}))'}))));
 }
 fs.writeFileSync(path.join(DIR,'grip-review.json'),JSON.stringify({times:[.75,2.25],hands:grip},null,2)+'\n');
 await c.call('risky_eval',{code:'Animation.all.find(a=>a.name==="animation.kart_idle").select()'});
 await c.call('animation_timeline',{action:'set_time',time:0});
}finally{try{await c.close();}catch{}}
