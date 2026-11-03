const fs=require('fs'),path=require('path'),vm=require('vm'),ts=require('typescript'),assert=require('assert'),React=require('react');
const slots=[],cache=new Map();let cursor=0;
const stub=()=>null;
const hooks={...React,useState(initial){const i=cursor++;if(!(i in slots))slots[i]=typeof initial==='function'?initial():initial;return [slots[i],value=>{slots[i]=typeof value==='function'?value(slots[i]):value;}];},useEffect:()=>{},useId:()=> 'skeleton-test'};
function load(file){file=path.resolve(file);if(file.endsWith('.json'))return JSON.parse(fs.readFileSync(file,'utf8'));if(cache.has(file))return cache.get(file).exports;const module={exports:{}};cache.set(file,module);
 function req(id){if(id==='react')return hooks;if(id==='react/jsx-runtime')return require(id);if(id==='next/link')return {__esModule:true,default:stub};
 if(id.includes('/use-topic-preset'))return {useTopicPreset:()=>{}};
 if(id.includes('/AppHeader'))return {AppHeader:stub};if(id.includes('/SimulationStage'))return {SimulationStage:stub};if(id.includes('/ReadAloud'))return {ReadAloud:stub};if(id.includes('/EmbedButton'))return {EmbedButton:stub};if(id.endsWith('.css'))return {};
 let target=id.startsWith('@/')?'src/'+id.slice(2):id.startsWith('.')?path.resolve(path.dirname(file),id):null;if(!target)return require(id);if(!path.extname(target))target+=fs.existsSync(target+'.ts')?'.ts':'.tsx';return load(target);}
 const code=ts.transpileModule(fs.readFileSync(file,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,jsx:ts.JsxEmit.ReactJSX,esModuleInterop:true}}).outputText;
 vm.runInNewContext(code,{module,exports:module.exports,require:req,console,Math,URLSearchParams,cancelAnimationFrame:()=>{}});return module.exports;
}
const data=load('src/lib/biology/skeleton.ts');assert.equal(data.BONES.length,24);assert.equal(new Set(data.BONES.map(b=>b.id)).size,24);
const sum=d=>data.BONES.filter(b=>b.division===d).reduce((s,b)=>s+b.count,0);assert.equal(sum('axial'),80);assert.equal(sum('appendicular'),126);
assert.equal(new Set(Array.from({length:24},(_,i)=>data.challengeBone(i).id)).size,24,'challenge sequence covers all groups');
const topic=JSON.parse(fs.readFileSync('src/lib/explorer/topics-data.json','utf8')).find(t=>t.id==='biology-skeletal-system');assert.equal(topic.parameters[0].max,data.BONES.length-1);
const {prepare}=load('src/lib/explorer/prepare.ts');for(const language of ['en','yo','ha','ig']){const r=prepare({prompt:'human skeleton',language});assert.equal(r.topicId,topic.id);assert(r.explanation.length>40);assert(r.url.startsWith('/biology/skeletal-system?'));}
const {SkeletalActivity}=load('src/components/biology/SkeletalActivity.tsx');
function nodes(tree){const list=[];function walk(n){if(!React.isValidElement(n))return;list.push(n);React.Children.forEach(n.props.children,walk);}walk(tree);return list;}
const text=n=>typeof n==='string'||typeof n==='number'?String(n):React.isValidElement(n)?React.Children.toArray(n.props.children).map(text).join(''):'';
function render(){cursor=0;return nodes(SkeletalActivity({embed:false}));}
let n=render();n.find(n=>n.type==='select'&&n.props.value==='explore').props.onChange({target:{value:'classify'}});
n=render();const correct=data.challengeBone(0).division;n.find(n=>n.type==='button'&&text(n)===correct).props.onClick();n=render();assert(n.some(n=>text(n)==='Score: 1/1 first attempts'));assert(n.filter(n=>n.type==='button'&&['axial','appendicular'].includes(text(n))).every(n=>n.props.disabled));
n.find(n=>n.type==='button'&&text(n)==='Reveal answer').props.onClick();n=render();assert(n.some(n=>text(n)==='Score: 1/1 first attempts'),'reveal cannot score a second attempt');
n.find(n=>n.type==='button'&&text(n)==='Reset activity').props.onClick();n=render();assert(n.some(n=>n.type==='select'&&n.props.value==='explore'));
n.find(n=>n.type==='button'&&text(n)==='Scapulae').props.onClick();n=render();const diagram=n.find(n=>n.props.onSelect&&n.props.division==='all'&&n.props.interactive);assert.equal(diagram.props.selected,'scapulae');assert.equal(diagram.props.view,'back');
console.log('PASS: 206-bone group totals, challenge coverage, four explainer languages, score locking/reveal, reset and back-view selection.');
