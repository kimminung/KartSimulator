import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {connect,textResult,saveImage} from './mcp-client.mjs';
const DIR=path.dirname(fileURLToPath(import.meta.url));fs.mkdirSync(path.join(DIR,'renders'),{recursive:true});
const c=await connect();
try{
 await c.call('create_offscreen_view',{id:'driver_review',width:1100,height:1100,copy_view:'none',antialias:true});
 const list=[['idle',0,'standing',[44,30,-60],[0,15,0],.58],['idle',0,'rear',[-44,30,60],[0,15,0],.58],['idle',0,'helmet_top',[16,68,-25],[0,26,0],1.0],['walk',.16,'walk',[44,28,-60],[0,15,0],.58],['run',.12,'run',[44,28,-60],[0,15,0],.58],['sit_down',.425,'sit_down',[38,26,-60],[0,11,-3],.66],['floor_sit',0,'floor_sit',[38,26,-60],[0,7,-3],.70],['kart_idle',0,'kart_pose',[40,30,-60],[0,15,-2],.58],['kart_idle',0,'gloves',[26,35,-42],[0,19,-8],1.15]];
 for(const [clip,time,name,position,target,zoom]of list){
  await c.call('risky_eval',{code:`(()=>{Animation.all.find(a=>a.name==='animation.${clip}').select();return Animation.selected.name;})()`});
  await c.call('animation_timeline',{action:'set_time',time});
  const image=await c.call('set_camera_angle',{view:'driver_review',position,target,projection:'orthographic',zoom,format:'png'});
  saveImage(image,path.join(DIR,'renders',name+'.png'));console.log(name);
 }
 for(const [clip,length]of [['walk',1.1],['run',.65]])for(let i=0;i<4;i++){
  await c.call('risky_eval',{code:`Animation.all.find(a=>a.name==='animation.${clip}').select()`});
  await c.call('animation_timeline',{action:'set_time',time:i*length/4});
  saveImage(await c.call('set_camera_angle',{view:'driver_review',position:[44,28,-60],target:[0,15,0],projection:'orthographic',zoom:.58,format:'png'}),path.join(DIR,'renders',`${clip}_${i}.png`));
 }
 await c.call('risky_eval',{code:'Animation.all.find(a=>a.name==="animation.kart_idle").select()'});
 await c.call('animation_timeline',{action:'set_time',time:0});
 saveImage(await c.call('set_camera_angle',{view:'driver_review',position:[55,16,-3],target:[0,11,-5],projection:'orthographic',zoom:1.1,format:'png'}),path.join(DIR,'renders','ankle_side.png'));
 await c.call('save_checkpoint',{name:'driver cream texture before night review'});
 for(const [name,file]of [['night','driver_01_skin_night.png'],['restore','driver_01_skin.png']]){
  const source=path.join(DIR,'../../Assets/blockbench/driver',file).replaceAll('\\','/');
  await c.call('risky_eval',{code:`(()=>{const t=Texture.all[0];Undo.initEdit({textures:[t],bitmap:true});t.fromDataURL('data:image/png;base64,'+requireNativeModule('fs').readFileSync('${source}').toString('base64'));Undo.finishEdit('${name} review texture');Canvas.updateAll();return t.name;})()`});
  if(name==='night'){
   await c.call('risky_eval',{code:'Animation.all.find(a=>a.name==="animation.idle").select()'});
   await c.call('animation_timeline',{action:'set_time',time:0});
   saveImage(await c.call('set_camera_angle',{view:'driver_review',position:[44,30,-60],target:[0,15,0],projection:'orthographic',zoom:.58,format:'png'}),path.join(DIR,'renders','night.png'));
  }
 }
}finally{await c.close();}
