const fs=require('fs'),vm=require('vm'),path=require('path'),ts=require('typescript'),assert=require('assert');
const slots=[];let index=0,pending=[],calls=[],angle;
const same=(a,b)=>a&&b&&a.length===b.length&&a.every((v,i)=>Object.is(v,b[i]));
const ctx=new Proxy({}, {get:(o,k)=>k in o?o[k]:(...args)=>calls.push([k,...args]),set:(o,k,v)=>(o[k]=v,true)});
const canvas={width:440,height:440,getContext:()=>ctx,getBoundingClientRect:()=>({left:10,top:20,width:400,height:400}),setPointerCapture(){}};
const react={useRef(v){const i=index++;return slots[i]??(slots[i]={current:i===0?canvas:v});},useCallback(fn,deps){const i=index++;if(!same(slots[i]?.deps,deps))slots[i]={deps,fn};return slots[i].fn;},useEffect(fn,deps){const i=index++;if(!same(slots[i],deps)){slots[i]=deps;pending.push(fn);}}};
function load(file){const module={exports:{}};const code=ts.transpileModule(fs.readFileSync(file,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,jsx:ts.JsxEmit.ReactJSX}}).outputText;vm.runInNewContext(code,{module,exports:module.exports,require:id=>id==='react'?react:id==='react/jsx-runtime'?{jsx:(type,props)=>({type,props})}:id.startsWith('@/')?load('src/'+id.slice(2)+'.ts'):require(id),Math});return module.exports;}
const Component=load('src/components/simulation/UnitCircleCanvas.tsx').UnitCircleCanvas;
function render(size){index=0;calls=[];pending=[];canvas.width=size;canvas.height=size;const node=Component({width:size,height:size,angleDeg:60,onAngleChange:v=>angle=v});pending.forEach(f=>f());return node;}
render(440);assert(calls.some(c=>c[0]==='arc'),'initial paint');
const large=render(1320);assert(calls.some(c=>c[0]==='arc'),'resize must repaint without a click or angle change');assert(calls.some(c=>c[0]==='setTransform'&&c[1]===3&&c[4]===3),'labels and geometry scale together');
large.props.onPointerDown({target:canvas,pointerId:1,clientX:410,clientY:220});assert(Math.abs(angle)<1e-8,'CSS-scaled pointer still maps rightwards to zero degrees');
console.log('PASS: initial paint, resize repaint with unchanged angle, proportional label scaling, and pointer coordinates.');
