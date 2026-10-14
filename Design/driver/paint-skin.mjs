// Blockbench Minecraft Style Guide: 제한 팔레트, 색상 변화가 있는 명암 램프,
// 형태를 설명하는 픽셀 덩어리와 재질 구분. 임의 노이즈·연속 RGB 그라데이션 없음.
export const ramps={
 coat:['#536A82','#839CAB','#BCCDD4','#E3EBE7','#FFF5D9'],
 navy:['#081224','#15253C','#29465F','#4D7084','#8BA6AD'],
 glass:['#030A17','#102842','#235575','#438DA4','#ACEEF0'],
 cyan:['#07384D','#12647C','#149DB6','#36CFD4','#A1EEEB'],
 rubber:['#060D18','#172235','#2C3D50','#4B5D6B','#82949C'],
 metal:['#29394B','#4D6175','#8397A5','#B6C7CE','#E9F0E6'],
 gold:['#694D29','#AC7731','#DFAC45','#FFE181','#FFF5CB']
};
const rgb=c=>c.match(/[0-9a-f]{2}/gi).map(x=>parseInt(x,16));
function inside(x,y,poly){let c=false;for(let i=0,j=poly.length-1;i<poly.length;j=i++)if((poly[i][1]>y)!==(poly[j][1]>y)&&x<(poly[j][0]-poly[i][0])*(y-poly[i][1])/(poly[j][1]-poly[i][1])+poly[i][0])c=!c;return c;}
const q=v=>(Math.floor(v*4)+.5)/4;
export function paintEntity(part,point,n){
 const [x,y,z]=point.map(q),cx=part.center[0],lx=q(x-cx),ax=Math.abs(x);
 let material='coat',value=n[1]>.45?4:n[2]<-.35?3:n[2]>.35?2:3,fixed=false;
 const mark=(m,v)=>{material=m;value=v;};
 const stroke=(a,b,w)=>Math.abs(a-b)<w;
 const rect=(u,v,a,b,c,d)=>u>=a&&u<c&&v>=b&&v<d;
 if(part.tag==='helmet'){
  mark('coat',3);
  if(z>1.35||x<-3.25) value=2;
  if(z<-3.0&&y<24.3) value=2;
  if(y>28.85){
   // 넓은 하이라이트와 그림자 덩어리로 도색 면을 표현한다.
   if(inside(x,z,[[.75,-3.5],[3.5,-2.5],[3.5,1.2],[1.25,.7]]))value=4;
   if(inside(x,z,[[-3.8,.8],[-1.3,1.25],[-1.3,3.5],[-3.8,3.5]]))value=1;
   if(inside(x,z,[[-3.8,-3.5],[-2.5,-3.5],[-3.0,-.4],[-3.8,.6]]))value=2;
   if(ax<.8)mark('cyan',z<.7?3:2);
   if(stroke(ax,1.55,.12)&&z>-.6&&z<2.8)mark('coat',1);
   if(rect(ax,z,2.1,.8,3.05,2.3)){
    mark('navy',1);if(stroke(z,1.0,.12)||stroke(z,1.5,.12)||stroke(z,2.0,.12))mark('metal',2);
   }
   if((stroke(ax,3.0,.14)&&stroke(z,-1.5,.14))||(stroke(ax,1.55,.14)&&stroke(z,2.4,.14)))mark('metal',3);
  }
  if(y<23.6)mark('navy',z<0?2:1);
  if(y>23.75&&y<24.35&&z<-3.6&&ax<1.6){mark('metal',2);if(stroke(ax,.375,.12)||stroke(ax,1.125,.12))mark('rubber',0);}
  if(z<-3.35&&y>=24.65&&y<28.15){
   mark('glass',0);
   // 유리의 파란 반사를 넓게 배치하고 가는 선을 흩뿌리지 않는다.
   if(inside(x,y,[[4.8,28.1],[4.8,25.4],[3.0,25.4],[.6,27.55],[-3.8,27.55],[-3.8,28.1]]))mark('glass',2);
   if(inside(x,y,[[4.1,27.85],[4.1,26.05],[3.1,26.05],[1.5,27.45],[-1.75,27.45],[-1.75,27.85]]))mark('glass',4);
   if(inside(x,y,[[-1.2,26.8],[.5,26.8],[1.3,26.15],[-.45,26.15]]))mark('glass',1);
   if(y<25.0||ax>4.1)mark('rubber',1);
   if(y>27.9)mark('cyan',3);
  }
  if(ax>3.7&&y>=24.5&&y<28.4){
   if(stroke(y,28.1,.12)||stroke(z,1.1,.12))mark('coat',1);
   if(rect(z,y,1.45,25.0,2.3,27.3))mark('coat',2);
   if(rect(z,y,1.45,27.05,2.3,27.3))mark('coat',4);
  }
  if(z>2.8&&y>25.0&&y<27.0){if(ax<1.5)mark('navy',1);if(ax<1.2&&(stroke(y,25.375,.12)||stroke(y,26.125,.12)))mark('metal',2);}
 }
 if(part.tag==='ear'){
  mark('navy',2);if(y<24.75||z>.8)mark('navy',1);
  if(y>24.95&&y<25.85&&Math.abs(x-cx)>.45)mark('cyan',3);
  if(stroke(y,25.375,.12)&&Math.abs(x-cx)>.45)mark('cyan',1);
  if(stroke(z,.875,.12)&&(stroke(y,24.625,.12)||stroke(y,26.125,.12)))mark('metal',4);
 }
 if(part.tag==='jacket'){
  const front=z<-1.7;
  mark(front?'coat':'navy',front?3:2);
  if(front){
   // 어깨 아래·옆구리·밑단의 주름을 구분되는 형태로 그린다.
   if(inside(x,y,[[3.8,20.8],[2.6,20.8],[1.8,19.5],[-1.8,19.5],[-2.7,20.6],[-3.8,20.6],[-3.8,18.5],[-2.7,18.8],[-1.4,19.2],[1.4,19.2],[2.75,18.9],[3.8,18.7]]))value=2;
   if(inside(x,y,[[1.2,18.95],[2.4,18.7],[2.2,16.8],[1.4,16.2],[1.2,17.1]]))value=4;
   if(inside(x,y,[[-3.0,14.4],[-1.6,15.5],[-.5,15.8],[-.5,15.3],[-2.0,14.4]]))value=1;
   if(inside(x,y,[[.5,14.8],[2.2,15.6],[3.0,15.6],[2.5,15.0],[1.6,14.7]]))value=2;
   if(ax>3.1)mark('navy',1);
   if(ax>2.6&&ax<3.05&&y>14.8&&y<19.7)mark('cyan',x>0?3:2);
   if(stroke(ax,2.25,.12)&&y>14.8&&y<17.2)mark('coat',1);
   if(rect(ax,y,1.25,15.2,2.25,16.1)){mark('coat',2);if(y>15.85)mark('coat',1);if(y<15.4)mark('coat',4);}
   if(ax<.25&&y>14.2&&y<19.2){mark('navy',1);if(Math.floor(y*4)%2===0)mark('metal',3);}
   if(ax<1.25&&y>16.35&&y<18.6){
    mark('navy',1);const u=Math.floor((1.25-x)*4),v=Math.floor((18.625-y)*4)-2;
    const zero=['111','101','101','101','111'],one=['010','110','010','010','111'];
    if(v>=0&&v<5&&((u>=1&&u<4&&zero[v][u-1]==='1')||(u>=6&&u<9&&one[v][u-6]==='1')))mark('coat',4),fixed=true;
   }
  }else{
   if(y>18.7)mark('navy',3);
   if(inside(ax,y,[[.3,17.3],[.75,17.3],[2.4,18.55],[2.4,17.9],[.75,16.65],[.3,16.65]]))mark('cyan',2);
   if(y<15.0)mark('navy',1);
   if(stroke(ax,2.75,.12)&&y>15.2&&y<18.7)mark('navy',4);
   if(inside(ax,y,[[1.1,15.1],[2.6,15.6],[3.8,15.6],[3.3,15.25],[1.7,14.85]]))mark('navy',3);
  }
 }
 if(part.tag==='upper_arm'||part.tag==='forearm'){
  mark('coat',3);
  if(Math.abs(lx)>.75)mark('navy',2);
  if(part.tag==='upper_arm'){
   if(y>18.2)mark('navy',y>19.0?3:1);
   if(y>18.5&&y<18.95)mark('cyan',3);
   if(y<15.4)mark('coat',1);
   if(inside(lx,y,[[-.6,16.0],[-.1,16.4],[.9,16.9],[.9,17.15],[-.2,16.75],[-.6,16.4]]))mark('coat',2);
   if(rect(lx,y,-.25,17.15,.65,17.75))mark('coat',4);
  }else{
   if(y<11.1)mark('cyan',2);if(y>13.8)mark('coat',1);
   if(inside(lx,y,[[-.65,11.75],[.05,12.2],[.9,12.2],[.9,12.5],[-.1,12.45],[-.65,12.0]]))mark('coat',1);
   if(inside(lx,y,[[-.6,12.65],[.2,13.1],[.8,13.1],[.8,13.35],[0,13.3],[-.6,12.9]]))mark('coat',2);
   if(stroke(y,10.875,.12))mark('metal',3);
  }
 }
 if(part.tag==='joint'||part.tag==='collar'){
  mark('rubber',Math.floor(y*4)%3===0?0:2);if(Math.abs(x-cx)<.3&&z<0)mark('rubber',3);
 }
 if(part.tag==='pelvis'){
  mark('navy',2);if(y<11.5)mark('navy',1);
  if(y>13.0)mark('rubber',1);
  if(y>13.1&&Math.floor(x*4)%3===0)mark('metal',2);
  if(z<-1.85&&ax<.7&&y>13.2){mark('gold',3);if(ax>.35)mark('gold',1);}
 }
 if(part.tag==='thigh'||part.tag==='shin'){
  mark('navy',2);if(z>0||lx<-.8)mark('navy',1);
  if(part.tag==='thigh'){
   if(z<-1.25&&Math.abs(lx)<.5&&y>8.0&&y<11.2)mark('cyan',3);
   if(inside(lx,y,[[-1.2,7.0],[-.6,7.65],[.5,8.2],[.9,8.2],[.3,7.65],[-.65,7.2]]))mark('navy',3);
   if(inside(lx,y,[[-1.25,9.75],[-.3,10.15],[.75,10.5],[.95,10.25],[.2,9.8],[-.7,9.45]]))mark('navy',1);
   if(stroke(lx,-1.125,.12)&&y>8.0&&y<10.8)mark('navy',4);
  }else{
   if(y>5.2&&z<-1.0){mark('coat',Math.abs(lx)<.6?3:2);if(y<5.55)mark('coat',1);if(lx>.6&&y>6.1)mark('coat',4);}
   else{mark('rubber',2);if(inside(lx,y,[[-1.0,3.2],[-.4,3.8],[.8,4.25],[1.0,4.6],[.0,4.2],[-1.0,3.55]]))mark('rubber',3);}
   if(y<2.7)mark('cyan',2);
  }
 }
 if(part.tag==='glove'){
  mark('navy',2);if(z<-.75)mark('rubber',1);
  if(Math.abs(n[1])>.5){
   mark('navy',2);
   if(Math.abs(z)<.75&&Math.abs(lx)<1.0){mark('metal',y<10?3:2);if(Math.floor((lx+1)*4)%3===0)mark('rubber',0);if(z>.25)mark('metal',4);}
  }
  if(z>1.0&&y>9.5&&y<10.4){mark('coat',3);if(Math.floor((lx+1.0)*4)%3===0)mark('navy',1);}
  if(z<-.8&&Math.floor((lx+y)*4)%4===0)mark('rubber',3);
  if(y>10.5)mark('cyan',2);
 }
 if(part.tag==='boot'){
  mark('rubber',2);if(z>1.0||x-cx<-.8)mark('rubber',1);
  if(z<-2.4){mark('coat',3);if(lx<-.6)mark('coat',2);if(y<.8)mark('coat',1);}
  if(inside(z,y,[[-2.3,1.6],[-1.0,2.5],[.75,2.5],[.75,2.1],[-.5,2.1],[-1.6,1.5]]))mark('rubber',3);
  if(z>-.8&&z<.85&&Math.abs(lx)<1.1&&y>2.25){mark('navy',1);if(Math.floor(z*4)%2===0)mark('metal',3);}
  if(Math.abs(lx)>1.35&&stroke(y,1.125,.12))mark('metal',2);
  if(y>.6&&y<.9)mark('cyan',2);
 }
 if(part.tag==='sole'){
  mark('rubber',1);if(Math.floor((z+Math.abs(lx)*.6)*4)%3===0)mark('rubber',3);if(y<.1)mark('rubber',0);
 }
 value=Math.max(0,Math.min(4,value));
 // 남색 도색에서도 인쇄·금속·그립의 식별성을 유지한다.
 const nightMaterial=material==='coat'&&!fixed?'navy':material;
 return {rgb:rgb(ramps[material][value]),rgbNight:rgb(ramps[nightMaterial][value])};
}
