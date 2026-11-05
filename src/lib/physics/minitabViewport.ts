/** Shared drawing/pointer geometry for Minitab's fixed-coordinate illustrations. */
export function fitMinitabViewport(width:number,height:number,logicalWidth:number,logicalHeight:number) {
 const scale=Math.max(0.001,Math.min(width/logicalWidth,height/logicalHeight));
 return {scale,x:(width-logicalWidth*scale)/2,y:(height-logicalHeight*scale)/2};
}
export function prepareMinitabCanvas(canvas:HTMLCanvasElement,ctx:CanvasRenderingContext2D,width:number,height:number) {
 const view=fitMinitabViewport(canvas.width,canvas.height,width,height);
 ctx.setTransform(1,0,0,1,0,0);
 ctx.clearRect(0,0,canvas.width,canvas.height);
 ctx.fillStyle='#f8fafc';ctx.fillRect(0,0,canvas.width,canvas.height);
 ctx.setTransform(view.scale,0,0,view.scale,view.x,view.y);
 return {W:width,H:height};
}
export function minitabPointer(canvas:HTMLCanvasElement,clientX:number,clientY:number,width:number,height:number) {
 const rect=canvas.getBoundingClientRect();
 const view=fitMinitabViewport(rect.width,rect.height,width,height);
 return {x:(clientX-rect.left-view.x)/view.scale,y:(clientY-rect.top-view.y)/view.scale};
}
