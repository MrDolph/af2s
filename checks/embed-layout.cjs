const fs=require('fs'),ts=require('typescript'),assert=require('assert');
let count=0;
for(const d of fs.readdirSync('src/app/embed',{withFileTypes:true}).filter(e=>e.isDirectory())){
 const file=`src/app/embed/${d.name}/page.tsx`,source=fs.readFileSync(file,'utf8'),ast=ts.createSourceFile(file,source,99,true,4);
 assert(source.includes('af-embed-stage'),`missing common embed class: ${d.name}`);
 assert(source.includes('data-stage-role="canvas"'),`missing canvas slot: ${d.name}`);
 let canvasCount=0;
 function tag(n){return (ts.isJsxElement(n)?n.openingElement:ts.isJsxSelfClosingElement(n)?n:null)?.tagName.getText(ast)||'';}
 function role(n){return ts.isJsxElement(n)?n.openingElement.attributes.properties.find(p=>p.name?.text==='data-stage-role')?.initializer?.text:undefined;}
 function walk(n){
  if(ts.isJsxSelfClosingElement(n)&&/Canvas$/.test(tag(n))){canvasCount++;for(const p of n.attributes.properties){if(p.name?.text==='width')assert(!(ts.isJsxExpression(p.initializer)&&ts.isNumericLiteral(p.initializer.expression)),`fixed width ${d.name}`);}}
  if(ts.isJsxSelfClosingElement(n)&&tag(n)==='SimulationControls'){let p=n.parent;while(p&&!role(p))p=p.parent;assert.equal(role(p),'playback',`playback inside wrong panel ${d.name}`);}
  if(ts.isJsxSelfClosingElement(n)&&/Graph$/.test(tag(n))){let p=n.parent;while(p&&!role(p))p=p.parent;assert.notEqual(role(p),'parameters',`graph inside header ${d.name}`);}
  ts.forEachChild(n,walk);
 }
 walk(ast);assert(canvasCount>0,`no canvas ${d.name}`);
 assert(source.includes('useResponsiveCanvasSize')||source.includes('AtomicModelsCanvas')||source.includes('MosfetCanvas'),`no sizing strategy ${d.name}`);
 count++;
}
assert.equal(count,35);
console.log(`PASS: ${count} embeds have shared stages, responsive canvases, separate playback and no auxiliary graphs in parameter headers.`);
