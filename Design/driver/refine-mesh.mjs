// mcbemodelingmasterAI의 경사진 연결면·면별 UV·위치 기준 채색 원칙을 자유형 메시로 적용한다.
// Bedrock geo의 X 반전은 여기의 Blockbench free 모델에 다시 적용하지 않는다.
import crypto from 'node:crypto';
import {paintEntity} from './paint-skin.mjs';
import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);let sharp;try{sharp=require('sharp');}catch{sharp=require('C:/Users/minsi/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');}
const uuid=s=>{const h=crypto.createHash('sha256').update('driver-01-mesh-v2/'+s).digest('hex');return `${h.slice(0,8)}-${h.slice(8,12)}-4${h.slice(13,16)}-a${h.slice(17,20)}-${h.slice(20,32)}`;};
const sub=(a,b)=>a.map((v,i)=>v-b[i]),dot=(a,b)=>a.reduce((s,v,i)=>s+v*b[i],0),cross=(a,b)=>[a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]];
export async function refine(model){
 const parts=[];
 function mesh(name,group,vertices,polygons,tag,center=[0,0,0]){
  const keys=vertices.map((_,i)=>'v'+i),faces={};const mid=vertices[0].map((_,axis)=>vertices.reduce((s,p)=>s+p[axis],0)/vertices.length);
  const supported=polygons.flatMap(ids=>ids.length<=4?[ids]:Array.from({length:ids.length-2},(_,i)=>[ids[0],ids[i+1],ids[i+2]]));
  for(const [i,indices]of supported.entries()){let ids=indices.slice();const p=ids.map(j=>vertices[j]),n=cross(sub(p[1],p[0]),sub(p[2],p[0]));const fc=p[0].map((_,axis)=>p.reduce((s,v)=>s+v[axis],0)/p.length);if(dot(n,sub(fc,mid))<0)ids.reverse();faces['f'+i]={vertices:ids.map(j=>keys[j]),uv:{},texture:0};}
  parts.push({name,type:'mesh',uuid:uuid(name),origin:[0,0,0],rotation:[0,0,0],vertices:Object.fromEntries(vertices.map((v,i)=>[keys[i],v])),faces,visibility:true,export:true,color:0,group,tag,center});
 }
 function prism(name,group,rings,tag,cx=0,cz=0){const points=[],faces=[];for(const [y,w,d,c]of rings)for(const [x,z]of [[-w+c,-d],[w-c,-d],[w,-d+c],[w,d-c],[w-c,d],[-w+c,d],[-w,d-c],[-w,-d+c]])points.push([cx+x,y,cz+z]);for(let r=0;r<rings.length-1;r++)for(let j=0;j<8;j++)faces.push([r*8+j,(r+1)*8+j,(r+1)*8+(j+1)%8,r*8+(j+1)%8]);faces.push(Array.from({length:8},(_,i)=>i),Array.from({length:8},(_,i)=>(rings.length-1)*8+i));mesh(name,group,points,faces,tag,[cx,0,cz]);}
 prism('pelvis','hip',[[10.05,3.1,1.85,.45],[11.2,3.5,2.1,.45],[13.75,3.45,2.1,.5],[14,3.2,1.85,.45]],'pelvis');
 prism('racing_jacket','body',[[13.7,3.2,1.88,.45],[14.4,3.65,2.15,.6],[19.65,4.0,2.3,.7],[20.8,3.25,1.95,.6]],'jacket');
 prism('neck_collar','neck',[[20.55,1.8,1.7,.45],[21,1.95,1.8,.5],[22.65,1.65,1.55,.45]],'collar');
 prism('helmet_shell','head',[[22.45,3.9,3.1,.9],[23.6,4.8,4.05,1.05],[28.85,4.8,4.05,1.05],[30.15,3.75,3.05,.85]],'helmet',0,-.2);
 for(const [s,sign]of [['l',1],['r',-1]]){
  const x=sign*5.1,lx=sign*2.05;
  prism('upper_arm_'+s,'arm_'+s,[[14.7,.95,1.25,.28],[15.1,1.05,1.35,.32],[18.15,1.15,1.45,.38],[18.9,1.43,1.65,.42],[20.15,1.1,1.3,.38]],'upper_arm',x);
  prism('elbow_'+s,'forearm_'+s,[[14.15,.9,1.17,.25],[15.3,.9,1.17,.25]],'joint',x);
  prism('forearm_'+s,'forearm_'+s,[[10.4,.94,1.18,.3],[10.75,1.14,1.42,.34],[13.9,1.08,1.35,.33],[14.9,.92,1.16,.3]],'forearm',x);
  prism('glove_palm_'+s,'hand_'+s,[[9.15,1.0,1.1,.3],[9.45,1.14,1.32,.33],[10.6,1.14,1.32,.33],[10.85,.97,1.1,.3]],'glove',x);
  prism('glove_thumb_'+s,'hand_'+s,[[9.6,.3,.68,.12],[10.15,.38,.74,.15],[10.45,.28,.6,.12]],'glove',x-sign*1.27,.1);
  prism('thigh_'+s,'thigh_'+s,[[6.35,1.37,1.48,.34],[6.75,1.55,1.65,.36],[11.3,1.6,1.75,.4],[11.88,1.35,1.5,.38]],'thigh',lx);
  prism('knee_'+s,'shin_'+s,[[5.9,1.17,1.22,.35],[7.05,1.17,1.22,.35]],'joint',lx);
  prism('shin_'+s,'shin_'+s,[[2.03,1.22,1.32,.35],[2.5,1.38,1.45,.38],[5.5,1.4,1.47,.38],[6.65,1.2,1.28,.35]],'shin',lx);
  prism('boot_cuff_'+s,'foot_'+s,[[1.85,1.25,1.32,.35],[2.6,1.35,1.4,.38],[3.25,1.05,1.12,.32]],'joint',lx);
  const profile=[[-3.1,.35],[-3.1,1.3],[-1.05,2.65],[1.65,2.65],[1.65,.35]];
  const pts=profile.flatMap(([z,y])=>[[lx-1.6,y,z],[lx+1.6,y,z]]),faces=[];for(let i=0;i<profile.length;i++){const j=(i+1)%profile.length;faces.push([i*2,j*2,j*2+1,i*2+1]);}faces.push(profile.map((_,i)=>i*2),profile.map((_,i)=>i*2+1));mesh('boot_'+s,'foot_'+s,pts,faces,'boot',[lx,0,0]);
  prism('boot_sole_'+s,'foot_'+s,[[0,1.7,2.5,.42],[.37,1.7,2.5,.42]],'sole',lx,-.68);
  const ex=sign*4.6;
  const ep=[[-.1,24.25,-1.55],[.65,24.5,-1.2],[.65,26.25,-1.2],[-.1,26.65,-1.55],[-.1,24.25,1.3],[.65,24.5,1],[.65,26.25,1],[-.1,26.65,1.3]].map(([a,y,z])=>[ex+sign*a,y,z]);
  mesh('helmet_side_'+s,'head',ep,[[0,1,2,3],[4,7,6,5],[0,4,5,1],[1,5,6,2],[2,6,7,3],[3,7,4,0]],'ear',[ex,0,0]);
 }
 const patches=[];
 for(const part of parts)for(const face of Object.values(part.faces)){
  const p=face.vertices.map(k=>part.vertices[k]),norm=cross(sub(p[1],p[0]),sub(p[2],p[0]));const length=Math.hypot(...norm);const n=norm.map(v=>v/length),axis=n.map(Math.abs).indexOf(Math.max(...n.map(Math.abs)));
  const axes=axis===0?[2,1]:axis===1?[0,2]:[0,1],sgn=axis===2&&n[2]<0?-1:1;
  const coords=p.map(p=>[p[axes[0]]*sgn,-p[axes[1]]]);const lo=[0,1].map(i=>Math.min(...coords.map(p=>p[i]))),hi=[0,1].map(i=>Math.max(...coords.map(p=>p[i])));
  const density=4,w=Math.max(1,Math.ceil((hi[0]-lo[0])*density)),h=Math.max(1,Math.ceil((hi[1]-lo[1])*density));patches.push({part,face,n,axis,axes,sgn,coords,lo,hi,w,h});
 }
 const WIDTH=512;let x=1,y=1,row=0;for(const p of patches.toSorted((a,b)=>b.h-a.h)){if(x+p.w+1>WIDTH){x=1;y+=row+2;row=0;}p.x=x;p.y=y;x+=p.w+2;row=Math.max(row,p.h);}const HEIGHT=2**Math.ceil(Math.log2(y+row+2));
 const raw=Buffer.alloc(WIDTH*HEIGHT*4),night=Buffer.alloc(raw.length);
 for(const p of patches){const {part,face,w,h,axes,axis,n,lo,hi,sgn}=p;const point0=part.vertices[face.vertices[0]],d=dot(n,point0);
  for(let j=0;j<h;j++)for(let i=0;i<w;i++){
   const q=[0,0,0];q[axes[0]]=(lo[0]+(hi[0]-lo[0])*(i+.5)/w)/sgn;q[axes[1]]=-(lo[1]+(hi[1]-lo[1])*(j+.5)/h);q[axis]=(d-n[axes[0]]*q[axes[0]]-n[axes[1]]*q[axes[1]])/n[axis];const colors=paintEntity(part,q,n);const at=((p.y+j)*WIDTH+p.x+i)*4;raw.set([...colors.rgb,255],at);night.set([...colors.rgbNight,255],at);
  }
  face.vertices.forEach((k,i)=>{face.uv[k]=[p.x+(p.coords[i][0]-lo[0])/(hi[0]-lo[0])*w,p.y+(p.coords[i][1]-lo[1])/(hi[1]-lo[1])*h];});
  for(let j=-1;j<=h;j++)for(let i=-1;i<=w;i++){if(i>=0&&i<w&&j>=0&&j<h)continue;const dst=((p.y+j)*WIDTH+p.x+i)*4,src=((p.y+Math.max(0,Math.min(h-1,j)))*WIDTH+p.x+Math.max(0,Math.min(w-1,i)))*4;raw.copy(raw,dst,src,src+4);night.copy(night,dst,src,src+4);}
 }
 const png=await sharp(raw,{raw:{width:WIDTH,height:HEIGHT,channels:4}}).png().toBuffer(),dark=await sharp(night,{raw:{width:WIDTH,height:HEIGHT,channels:4}}).png().toBuffer();
 model.elements=parts.map(({group,tag,center,...p})=>p);const groupById=new Map(model.groups.map(g=>[g.uuid,g]));function children(nodes){for(const node of nodes){if(typeof node==='string')continue;const b=groupById.get(node.uuid);node.children=node.children.filter(c=>typeof c!=='string');node.children.push(...parts.filter(p=>p.group===b.name).map(p=>p.uuid));children(node.children);}}children(model.outliner);
 model.resolution={width:WIDTH,height:HEIGHT};model.textures[0]={...model.textures[0],width:WIDTH,height:HEIGHT,uv_width:WIDTH,uv_height:HEIGHT,source:'data:image/png;base64,'+png.toString('base64')};
 return {model,png,dark,meshes:parts.length,faces:patches.length,width:WIDTH,height:HEIGHT};
}
