const fs=require('fs'),path=require('path'),vm=require('vm'),assert=require('assert'),ts=require('typescript');
const cache=new Map();let hooks=null;
const jsx=(type,props)=>({type,props});
function load(file){file=path.resolve(file);if(cache.has(file))return cache.get(file).exports;const m={exports:{}};cache.set(file,m);
 const source=ts.transpileModule(fs.readFileSync(file,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,jsx:ts.JsxEmit.ReactJSX}}).outputText;
 const requireFile=id=>{if(id==='react')return {useRef:v=>hooks.ref(v),useEffect:f=>hooks.effect(f),useCallback:f=>f,useMemo:f=>f()};if(id==='react/jsx-runtime')return {jsx,jsxs:jsx};if(id==='recharts')return new Proxy({},{get:(_,key)=>key});if(id.startsWith('@/'))return load('src/'+id.slice(2)+'.ts');return require(id);};
 vm.runInNewContext(source,{module:m,exports:m.exports,require:requireFile,requestAnimationFrame:f=>{hooks.frame=f;return 1},cancelAnimationFrame:()=>{},performance:{now:()=>1000},window:{devicePixelRatio:1},Math,console},{filename:file});return m.exports;
}
function canvasHarness(file,name,props,width,height){
 const calls=[];const ctx=new Proxy({createRadialGradient:()=>({addColorStop(){}}),createLinearGradient:()=>({addColorStop(){}})}, {get:(o,k)=>k in o?o[k]:(...args)=>calls.push([k,...args]),set:(o,k,v)=>(o[k]=v,true)});
 const canvas={width,height,getContext:()=>ctx};let count=0;
 hooks={ref:v=>({current:count++===0?canvas:v}),effect:f=>f(),frame:null};
 const node=load(file)[name]({...props,width,height});
 return {calls,node,frame(time){calls.length=0;hooks.frame(time);return [...calls];}};
}
const conical=canvasHarness('src/components/simulation/ConicalPendulumCanvas.tsx','ConicalPendulumCanvas',{length:1,theta_deg:45,mass:1,isRunning:true,isPaused:false},320,300);
conical.frame(0);let ys=[];
for(let t=100;t<=1200;t+=100){const calls=conical.frame(t),orbit=calls.find(c=>c[0]==='ellipse'),bob=calls.find(c=>c[0]==='arc'&&c[3]===12);assert(orbit&&bob);const [,cx,cy,rx,ry]=orbit;const [,x,y]=bob;assert(Math.abs(((x-cx)/rx)**2+((y-cy)/ry)**2-1)<1e-8);assert(x>=12&&x<=308&&y>=12&&y<=288);ys.push(y);}
assert(Math.max(...ys)-Math.min(...ys)>10,'bob must have perspective depth, not just horizontal motion');
for(const width of [280,390,1000]){
 const c=canvasHarness('src/components/simulation/CollisionCanvas.tsx','CollisionCanvas',{params:{m1:2,m2:2,u1:10,u2:0,type:'elastic',e:1},isRunning:true,isPaused:false},width,280);
 for(let t=0;t<=2500;t+=50){const calls=c.frame(t);const blocks=calls.filter(x=>x[0]==='roundRect');assert(blocks.length===4);for(const [,x,,w]of blocks)assert(x>=0&&x+w<=680,'both blocks must remain in camera');}
}
function walking(speed){const c=canvasHarness('src/components/simulation/WalkingCanvas.tsx','WalkingCanvas',{isRunning:true,isPaused:false,frictionEnabled:true,surfaceMass:70,speed},600,300);c.frame(0);return c.frame(100).find(x=>x[0]==='arc'&&x[3]===12)[1];}
assert(walking(0)===100);assert(Math.abs((walking(2)-100)-2*(walking(1)-100))<1e-8);
const band=load('src/lib/physics/bandTheory.ts');
for(const T of [0,100,300,600,1000])for(const d of ['intrinsic','n-type','p-type']){
 const c=band.carrierConcentrations(1.12,T,d,1e16);assert(Object.values(c).every(Number.isFinite));assert(Number.isFinite(band.dopedFermiLevel(1.12,T,d,1e16)));
 if(T>0){assert(Math.abs(c.n*c.p-c.ni*c.ni)<=Math.max(1,c.ni*c.ni)*1e-12);const expected=d==='intrinsic'?0:d==='n-type'?1e16:-1e16;assert(Math.abs(c.n-c.p-expected)<=1e16*1e-12);}
}
assert(band.fermiDirac(.56,.56,300)===.5);assert(band.fermiDirac(0,.56,300)>.99);
const carriers=band.generateCarriers(band.MATERIALS.silicon,300,'intrinsic',0);assert(carriers.some(c=>c.type==='electron'&&c.band==='valence'));assert(carriers.filter(c=>c.type==='hole').every(c=>c.energy<=0));
let evolved=carriers;for(let i=0;i<1000;i++)evolved=band.updateCarriers(evolved,.05,300,3);assert(evolved.every((c,i)=>c.energy===carriers[i].energy&&c.y===carriers[i].y));
hooks={effect:()=>{},ref:v=>({current:v})};
const graph=load('src/components/simulation/DecayCanvas.tsx').DecayGraph;
for(const t of [0,1,5,10,20]){
 const node=graph({n0:100,halfLife:5,currentT:t});const data=node.props.children.props.data;assert(data.every(p=>p.t<=t));const last=data.at(-1);assert(Math.abs(last.n-100*2**(-t/5))<1e-8);
}
const field=canvasHarness('src/components/simulation/ElectricFieldCanvas.tsx','ElectricFieldCanvas',{configuration:'dipole',testX:.5,testY:.5,isRunning:false,isPaused:false,onTestPositionChange:(x,y)=>{field.position=[x,y]}},320,280);
const target={getBoundingClientRect:()=>({left:20,top:10,width:200,height:100}),setPointerCapture:()=>{},hasPointerCapture:()=>true};field.node.props.onPointerDown({currentTarget:target,pointerId:1,clientX:170,clientY:40});assert(Math.abs(field.position[0]-.75)<1e-8&&Math.abs(field.position[1]-.3)<1e-8);
console.log('PASS: conical orbit, collision camera at three widths, walking speed, carrier conservation/allowed energies, progressive decay, touch coordinate mapping.');
