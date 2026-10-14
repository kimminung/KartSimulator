import fs from 'node:fs';import path from 'node:path';import {fileURLToPath} from 'node:url';
import {connect,textResult} from './mcp-client.mjs';
import {assertGeneratedUnchanged,recordGeneratedState} from './generated-state.mjs';
assertGeneratedUnchanged();
const DIR=path.dirname(fileURLToPath(import.meta.url)),REPO=path.resolve(DIR,'../..');
const c=await connect();
try{
 const state=JSON.parse(textResult(await c.call('risky_eval',{code:'({name:Project.name,meshes:Mesh.all.length,bones:Group.all.length,clips:Animation.all.length})'})));
 if(state.meshes!==28||state.bones!==17||state.clips!==7)throw new Error('운전자만 있는 검토 프로젝트에서 내보내야 합니다.');
 const project=await c.call('export_model',{codec_id:'project',max_content_length:2000000,result_format:'embedded'});
 const resource=project.content.find(c=>c.type==='resource'&&c.resource.text);if(!resource)throw new Error('bbmodel export incomplete');
 fs.writeFileSync(path.join(REPO,'Assets/blockbench/driver/driver_01.bbmodel'),resource.resource.text);
 const glb=await c.call('export_model',{codec_id:'gltf',options:{encoding:'binary',scale:16,embed_textures:true,armature:false,animations:true},max_content_length:2000000,result_format:'embedded'});
 const binary=glb.content.find(c=>c.type==='resource'&&c.resource.blob);if(!binary)throw new Error('GLB export incomplete');
 fs.mkdirSync(path.join(REPO,'Assets/export/glb'),{recursive:true});const bytes=Buffer.from(binary.resource.blob,'base64');fs.writeFileSync(path.join(REPO,'Assets/export/glb/driver_01.glb'),bytes);
 recordGeneratedState();
 console.log(JSON.stringify({...state,bbmodelBytes:resource.resource.text.length,glbBytes:bytes.length}));
}finally{await c.close();}
