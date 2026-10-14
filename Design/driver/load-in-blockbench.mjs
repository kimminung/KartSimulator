import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {connect,textResult} from './mcp-client.mjs';
const DIR=path.dirname(fileURLToPath(import.meta.url)),REPO=path.resolve(DIR,'../..');
const model=JSON.parse(fs.readFileSync(path.join(REPO,'Assets/blockbench/driver/driver_01.bbmodel')));
const c=await connect();
try{
 const pre=await c.call('risky_eval',{code:'({name:Project.name,format:Format.id,elements:Outliner.elements.length})'});console.log(textResult(pre));
 if(JSON.parse(textResult(pre)).elements!==0)throw new Error('빈 작업본에서만 모델을 로드합니다. 기존 모델을 보존합니다.');
 await c.call('save_checkpoint',{name:'driver 01 before generated original geometry'});
 const sourcePath=path.join(REPO,'Assets/blockbench/driver/driver_01.bbmodel').replaceAll('\\','/');
 const code=`(()=>{Undo.initEdit({elements:[],outliner:true,textures:[]});Codecs.project.parse(JSON.parse(requireNativeModule('fs').readFileSync('${sourcePath}','utf8')),'driver_01.bbmodel');Undo.finishEdit('Original helmet racer geometry and skin');Canvas.updateAll();return {cubes:Cube.all.length,meshes:Mesh.all.length,bones:Group.all.length,textures:Texture.all.length};})()`;
 console.log(textResult(await c.call('risky_eval',{code})));
 const outline=JSON.parse(textResult(await c.call('list_outline',{include_cubes:false,include_meshes:false,max_depth:8})));console.log(JSON.stringify(outline.counts));
 console.log(textResult(await c.call('list_textures')));
 await c.call('save_checkpoint',{name:'driver 01 geometry before seven animation clips'});
 await c.call('set_mode',{mode_id:'animate'});
 for(const clip of JSON.parse(fs.readFileSync(path.join(DIR,'animation-spec.json')))){
   console.log(textResult(await c.call('create_animation',clip)));
 }
 console.log(textResult(await c.call('list_export_formats',{only_current_format:true})));
}finally{await c.close();}
