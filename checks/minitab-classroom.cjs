const fs=require('fs'),path=require('path'),vm=require('vm'),ts=require('typescript'),assert=require('assert'),React=require('react');
let index=0,slots=[],pending=[],calls=[],ticks=[],rect={left:10,top:20,width:400,height:400};
const same=(a,b)=>a&&b&&a.length===b.length&&a.every((v,i)=>Object.is(v,b[i]));
const ctx=new Proxy({}, {get:(o,k)=>k in o?o[k]:(...a)=>calls.push([k,...a]),set:(o,k,v)=>(o[k]=v,true)});
const canvas={width:480,height:480,getContext:()=>ctx,getBoundingClientRect:()=>rect,setPointerCapture(){}};
const react={...React,useMemo:fn=>fn(),useRef(v){const i=index++;return slots[i]??(slots[i]={current:i===0?canvas:v});},useCallback(fn,deps){const i=index++;if(!same(slots[i]?.deps,deps))slots[i]={deps,fn};return slots[i].fn;},useEffect(fn,deps){const i=index++;if(!same(slots[i],deps)){slots[i]=deps;pending.push(fn);}}};
function load(file){file=path.resolve(file);const module={exports:{}};const code=ts.transpileModule(fs.readFileSync(file,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,jsx:ts.JsxEmit.ReactJSX,esModuleInterop:true}}).outputText;const req=id=>id==='react'?react:id==='react/jsx-runtime'?require(id):id==='recharts'?new Proxy({}, {get:(_,key)=>key}):id.startsWith('@/')?load('src/'+id.slice(2)+'.ts'):require(id);vm.runInNewContext(code,{module,exports:module.exports,require:req,Math,URLSearchParams,requestAnimationFrame:()=>1,cancelAnimationFrame:()=>{}});return module.exports;}
const {fitMinitabViewport:fit,minitabPointer:pointer}=load('src/lib/physics/minitabViewport.ts');
for(const [w,h]of [[320,480],[800,800],[1600,900],[2400,1200]]){const v=fit(w,h,480,480);assert(Math.abs(v.x+240*v.scale-w/2)<1e-8);assert(Math.abs(v.y+240*v.scale-h/2)<1e-8);assert(480*v.scale<=w+1e-8&&480*v.scale<=h+1e-8);}
rect={left:10,top:20,width:1000,height:400};let p=pointer(canvas,510,220,480,480);assert.equal(p.x,240);assert.equal(p.y,240);
for(const name of ['EigenvectorCanvas','GradientExplorerCanvas','DivStokesCanvas','DampedOscillatorCanvas']){
 slots=[];index=0;let moved;
 const Component=load('src/components/simulation/'+name+'.tsx')[name];const base=name==='EigenvectorCanvas'?460:name==='DampedOscillatorCanvas'?380:480;const baseH=name==='DampedOscillatorCanvas'?300:base;
 const props={matrix:{a:1,b:0,c:0,d:1},t:0,fieldIndex:0,disk:{cx:0,cy:0,r:1},point:{x:0,y:0},angleDeg:45,onDiskChange:v=>moved=v,onPointChange:v=>moved=v,onAngleChange:()=>{},gamma:0.3,omega0:2,y0:1,yp0:0,isRunning:false,isPaused:false,onTick:t=>ticks.push(t)};
 function render(w,h){index=0;pending=[];calls=[];canvas.width=w;canvas.height=h;const node=Component({...props,width:w,height:h});pending.forEach(f=>f());return node;}
 render(base,baseH);assert(calls.some(c=>c[0]==='setTransform'&&c[1]===1));const enlarged=render(base*3,baseH*3);assert(calls.some(c=>c[0]==='setTransform'&&c[1]===3&&c[4]===3),name+' must scale the actual drawing and repaint when resized');
 if(name==='DivStokesCanvas'||name==='GradientExplorerCanvas'){
  const scale=400/480,unit=70;
  enlarged.props.onPointerDown({target:canvas,pointerId:1,clientX:510,clientY:220});
  enlarged.props.onPointerMove({clientX:510+unit*scale,clientY:220});
  assert(Math.abs((moved.cx??moved.x)-1)<1e-8,name+' drag uses centred letterboxed coordinates');assert(Math.abs(moved.cy??moved.y)<1e-8);enlarged.props.onPointerCancel();
 }
 if(name==='DampedOscillatorCanvas')assert(ticks.every(t=>t===0),'resize must not advance a stopped oscillator');
}
function nodes(tree){let out=[];function walk(n){if(!React.isValidElement(n))return;out.push(n);React.Children.forEach(n.props.children,walk);}walk(tree);return out;}
const targets=load('src/lib/physics/fourierSeries.ts').TARGETS,pairs=load('src/lib/physics/fourierTransform.ts').PAIRS;
for(const [file,fn,props]of [['LegendreBesselGraph','LegendreBesselGraph',{mode:'legendre',shown:[0,1]}],['FourierTransformGraph','FourierTransformGraph',{pair:pairs[0],a:1}],['FourierSeriesGraph','FourierSeriesGraph',{target:targets[0],n:3}],['GammaGraph','GammaGraph',{x:2,showNegative:false}],['HermiteLaguerreDeltaGraph','HermiteLaguerreGraph',{mode:'hermite',shown:[0,1]}],['HermiteLaguerreDeltaGraph','DiracDeltaGraph',{eps:.5,fname:'constant'}],['DampedOscillatorGraph','DampedOscillatorGraph',{gamma:.3,omega0:2,y0:1,yp0:0}]]){const C=load('src/components/simulation/'+file+'.tsx')[fn];const n=nodes(C(props));const container=n.find(x=>x.type==='ResponsiveContainer');assert.equal(container.props.height,'100%');assert(n.some(x=>x.props.className==='af-minitab-plot'&&x.props.style.height.includes('--af-minitab-plot-height')));}
const pages=fs.readdirSync('src/app/minitab').filter(name=>fs.existsSync(`src/app/minitab/${name}/page.tsx`)).filter(name=>fs.readFileSync(`src/app/minitab/${name}/page.tsx`,'utf8').includes('MinitabStage'));
assert.equal(pages.length,9);assert(fs.readFileSync('src/app/minitab/damped-oscillator/page.tsx','utf8').includes('data-stage-role="playback"'));assert(fs.readFileSync('src/app/minitab/gradient-explorer/page.tsx','utf8').includes('af-minitab-canvas-frame'));
console.log('PASS: all nine Minitab activities use scoped classroom layout; drawings scale and centre, resize paints stopped states, dragging survives letterboxing, and charts fill measured space.');

const {dampedEmbedSettings:settings}=load('src/lib/physics/dampedEmbed.ts');
const embedded=settings('?gamma=0.15&omega0=4.55&y0=-0.6&yp0=4');assert.equal(embedded.gamma,.15);assert.equal(embedded.omega0,4.55);assert.equal(embedded.y0,-.6);assert.equal(embedded.yp0,4);
assert.equal(settings('?gamma=Infinity&omega0=-3&y0=&yp0=100').gamma,.8);assert.equal(settings('?omega0=-3').omega0,.5);assert.equal(settings('?y0=').y0,1);assert.equal(settings('?yp0=100').yp0,4);
assert(fs.existsSync('src/app/embed/damped-oscillator/page.tsx'));
console.log('PASS: damped embed query values, defaults and bounds.');
