// 설치된 Blockbench MCP와 같은 로컬 API를 쓰는 작업용 클라이언트.
import fs from 'node:fs';
const endpoint='http://127.0.0.1:3000/bb-mcp';
export async function connect(){
  let id=1;
  const headers={'Content-Type':'application/json',Accept:'application/json, text/event-stream'};
  const response=await fetch(endpoint,{method:'POST',headers,body:JSON.stringify({jsonrpc:'2.0',id:id++,method:'initialize',params:{protocolVersion:'2024-11-05',capabilities:{},clientInfo:{name:'codex-driver-local',version:'1'}}})});
  if(!response.ok)throw new Error(`MCP initialize ${response.status}`);
  headers['mcp-session-id']=response.headers.get('mcp-session-id');
  await fetch(endpoint,{method:'POST',headers,body:JSON.stringify({jsonrpc:'2.0',method:'notifications/initialized'})});
  async function rpc(method,params){
    const response=await fetch(endpoint,{method:'POST',headers,body:JSON.stringify({jsonrpc:'2.0',id:id++,method,params})});
    const raw=await response.text();
    const data=JSON.parse(raw.startsWith('data:')?raw.split('\n').find(s=>s.startsWith('data:')).slice(5):raw);
    if(data.error)throw new Error(JSON.stringify(data.error));
    if(data.result?.isError)throw new Error(JSON.stringify(data.result));
    return data.result;
  }
  return {rpc,call:(name,args={})=>rpc('tools/call',{name,arguments:args}),close:()=>fetch(endpoint,{method:'DELETE',headers})};
}
export function textResult(r){return r.content?.filter(c=>c.type==='text').map(c=>c.text).join('\n')||'';}
export function saveImage(r,path){const i=r.content.find(c=>c.type==='image');if(!i)throw new Error('MCP render returned no image');fs.writeFileSync(path,Buffer.from(i.data,'base64'));}
