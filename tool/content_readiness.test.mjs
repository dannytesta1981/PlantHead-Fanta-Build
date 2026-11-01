import test from 'node:test';
import assert from 'node:assert/strict';
import {JSDOM} from 'jsdom';
import {readFileSync} from 'node:fs';
const source=readFileSync(new URL('../assets/content_readiness.js',import.meta.url),'utf8');
function page(html,ready='interactive',url='https://leghe.fantacalcio.it/') {
 const d=new JSDOM(html,{url,runScripts:'outside-only'});
 Object.defineProperty(d.window.document,'readyState',{value:ready});
 const rect={width:100,height:30,top:10,left:10,right:110,bottom:40};
 d.window.Element.prototype.getBoundingClientRect=()=>rect;
 d.window.Range.prototype.getBoundingClientRect=()=>rect;
 return d;
}
test('interactive or complete empty document is not usable',()=>{
 for(const ready of ['interactive','complete'])assert.equal(page('',ready).window.eval(source),false);
 assert.equal(page('<p>Contenuto</p>','loading').window.eval(source),false);
});
test('templates hidden ancestors inert content and opacity zero are excluded',()=>{
 for(const html of ['<template><p>LOGIN</p></template>','<div hidden>LOGIN</div>','<div style="display:none"><input></div>','<div style="visibility:hidden">LOGIN</div>','<div style="opacity:0"><button>LOGIN</button></div>','<div inert><input></div>','<script>LOGIN</script>'])assert.equal(page(html).window.eval(source),false,html);
});
test('visible real text is usable without waiting for complete',()=>{
 assert.equal(page('<main><p>Pagina ufficiale</p></main>').window.eval(source),true);
});
test('visible enabled controls count without reading or changing their values',()=>{
 const d=page('<input type="password" value="DO_NOT_EXPORT">');
 assert.equal(d.window.eval(source),true);
 assert.equal(d.window.document.querySelector('input').value,'DO_NOT_EXPORT');
 assert.equal(page('<input disabled>').window.eval(source),false);
 assert.equal(page('<input type="hidden">').window.eval(source),false);
});
test('empty frames and unloaded images do not mask an empty document',()=>{
 assert.equal(page('<iframe></iframe><img>').window.eval(source),false);
 const d=page('<img>');const img=d.window.document.querySelector('img');
 Object.defineProperty(img,'complete',{value:true});Object.defineProperty(img,'naturalWidth',{value:200});
 assert.equal(d.window.eval(source),true);
});
test('offscreen and zero-sized content is not renderable',()=>{
 for(const rect of [{width:0,height:0,top:0,left:0,right:0,bottom:0},{width:100,height:30,top:5000,left:10,right:110,bottom:5030}]) {
  const d=page('<p>Contenuto</p>');d.window.Element.prototype.getBoundingClientRect=()=>rect;
  d.window.Range.prototype.getBoundingClientRect=()=>rect;
  assert.equal(d.window.eval(source),false);
 }
});
test('initial blank document cannot be reported as official content',()=>{
 assert.equal(page('<p>Contenuto</p>','complete','about:blank').window.eval(source),false);
});

test("aria-hidden alone is not visual concealment",()=>{assert.equal(page('<p aria-hidden="true">Testo visibile</p>').window.eval(source),true);});


// JSDOM has no layout engine: stub the body, element and text Range boxes
// separately, so a collapsed body does not incorrectly collapse its descendants.
const zero={width:0,height:0,top:0,left:0,right:0,bottom:0};
const outside={width:100,height:30,top:5000,left:10,right:110,bottom:5030};
function collapsed(html,bodyRect=zero) {
 const d=page(html);
 d.window.document.body.getBoundingClientRect=()=>bodyRect;
 return d;
}
test('zero-sized body permits visible absolute or fixed descendants',()=>{
 for(const position of ['absolute','fixed']) {
  const d=collapsed(`<div style="position:${position}"><p>Testo reale</p></div>`);
  assert.equal(d.window.eval(source),true);
 }
 assert.equal(collapsed('<button>Controllo</button>').window.eval(source),true);
});
test('anomalous body outside viewport does not veto visible descendants',()=>{
 assert.equal(collapsed('<p>Visibile</p>',outside).window.eval(source),true);
});
test('text Range proves visibility even without a parent layout box',()=>{
 const d=collapsed('Testo diretto nel body');
 assert.equal(d.window.eval(source),true);
 const c=collapsed('<span style="display:contents">Testo</span>');
 c.window.document.querySelector('span').getBoundingClientRect=()=>zero;
 assert.equal(c.window.eval(source),true);
});
test('collapsed empty body and geometry alone never prove readiness',()=>{
 for(const html of ['', '<div></div>', '<template>Testo</template>', '<iframe></iframe>'])
  assert.equal(collapsed(html).window.eval(source),false,html);
});
test('collapsed body preserves hidden child and hidden ancestor exclusions',()=>{
 for(const html of ['<p hidden>Testo</p>','<div style="display:none"><button>Testo</button></div>','<div style="visibility:hidden"><p>Testo</p></div>','<div style="opacity:0"><input></div>','<div inert><button>Testo</button></div>'])
  assert.equal(collapsed(html).window.eval(source),false,html);
 for(const style of ['display:none','visibility:hidden','opacity:0']) {
  const d=collapsed('<p>Testo</p><button>Controllo</button>');d.window.document.body.style.cssText=style;
  assert.equal(d.window.eval(source),false,style);
 }
});
test('collapsed body does not admit zero-sized or offscreen text and controls',()=>{
 for(const rect of [zero,outside]) {
  const d=collapsed('<p>Testo</p><button>Controllo</button>');
  d.window.Element.prototype.getBoundingClientRect=()=>rect;
  d.window.Range.prototype.getBoundingClientRect=()=>rect;
  assert.equal(d.window.eval(source),false);
 }
});
