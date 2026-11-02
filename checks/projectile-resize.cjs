const fs=require('fs'),vm=require('vm'),path=require('path'),ts=require('typescript'),assert=require('assert');
const slots=[];let index=0,pending=[],calls=[],angle;
const same=(a,b)=>a&&b&&a.length===b.length&&a.every((v,i)=>Object.is(v,b[i]));
const ctx=new Proxy({createLinearGradient:()=>({addColorStop(){}}),createRadialGradient:()=>({addColorStop(){}})}, {get:(o,k)=>k in o?o[k]:(...args)=>calls.push([k,...args]),set:(o,k,v)=>(o[k]=v,true)});
const canvas={width:440,height:440,getContext:()=>ctx,getBoundingClientRect:()=>({left:10,top:20,width:400,height:400}),setPointerCapture(){}};
const react={useRef(v){const i=index++;return slots[i]??(slots[i]={current:i===0?canvas:v});},useState(v){index++;return [v,()=>{}];},useMemo(fn,deps){const i=index++;if(!same(slots[i]?.deps,deps))slots[i]={deps,value:fn()};return slots[i].value;},useCallback(fn,deps){const i=index++;if(!same(slots[i]?.deps,deps))slots[i]={deps,fn};return slots[i].fn;},useEffect(fn,deps){const i=index++;if(!same(slots[i],deps)){slots[i]=deps;pending.push(fn);}}};
function load(file){const module={exports:{}};const code=ts.transpileModule(fs.readFileSync(file,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,jsx:ts.JsxEmit.ReactJSX}}).outputText;vm.runInNewContext(code,{module,exports:module.exports,require:id=>id==='react'?react:id==='react/jsx-runtime'?{jsx:(type,props)=>({type,props}),jsxs:(type,props)=>({type,props})}:id.startsWith('@/')?load('src/'+id.slice(2)+'.ts'):require(id),Math,requestAnimationFrame:f=>{frame=f;return 1;},cancelAnimationFrame:()=>{}});return module.exports;}
let frame;
const Component=load('src/components/simulation/ProjectileModeCanvas.tsx').ProjectileModeCanvas;
const standard={v0:30,angle:45,g:9.81,h0:0};
function render(width,height,isRunning=false,isPaused=false){index=0;calls=[];pending=[];canvas.width=width;canvas.height=height;const node=Component({width,height,mode:'standard',standard,isRunning,isPaused});pending.forEach(f=>f());return node;}
render(680,300);assert(calls.some(c=>c[0]==='fillRect'),'initial stopped preview');
render(1200,600);assert(calls.some(c=>c[0]==='fillRect'),'fullscreen resize must paint before Run');assert.equal(slots[2].current.t,0,'preview must not advance time');
render(1200,600,true);frame(0);frame(16);const t=slots[2].current.t,x=slots[2].current.x;assert(t>0);
render(900,500,true,true);assert(calls.some(c=>c[0]==='fillRect'),'paused resize must paint');assert.equal(slots[2].current.t,t,'resize must not restart or advance time');assert.equal(slots[2].current.x,x,'resize must preserve projectile position');
console.log('PASS: stopped and paused resize repaint; simulation time and position preserved.');
