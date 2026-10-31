import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {JSDOM} from 'jsdom';
const source=readFileSync(new URL('../assets/access_bridge.js',import.meta.url),'utf8');
function page(html,url='https://leghe.fantacalcio.it/') {
 const d=new JSDOM(html,{url,runScripts:'outside-only'});
 for(const e of d.window.document.querySelectorAll('button,input'))e.getBoundingClientRect=()=>({width:100,height:20});
 d.window.eval(source);return d;
}
test('opens existing login modal, never follows the broken anchor or submits',()=>{
 const d=page('<a href="/login">LOGIN</a><button data-toggle="modal" data-target="#publicLogin">LOGIN</button><div id="publicLogin" role="dialog" style="display:none"><form><input type="password" value="FAKE_REJECTION_FIXTURE"></form></div>');
 const input=d.window.document.querySelector('input');let shown=false, submits=0, anchors=0;
 input.getBoundingClientRect=()=>({width:shown?100:0,height:20});
 d.window.document.querySelector('form').onsubmit=()=>submits++;
 d.window.document.querySelector('a').onclick=()=>anchors++;
 d.window.document.querySelector('button').onclick=()=>shown=true;
 assert.equal(d.window.__phAccessBridge.open(),'requested');
 assert.equal(d.window.__phAccessBridge.probe().passwordVisible,true);
 assert.equal(anchors,0);assert.equal(submits,0);
 assert.ok(!JSON.stringify(d.window.__phAccessBridge.probe()).includes('FAKE_REJECTION_FIXTURE'));
});
test('unknown, ambiguous and submit controls are not activated',()=>{
 const d=page('<form><button data-toggle="modal" data-target="#x">LOGIN</button></form><div role="dialog" id="x"><form><input type="password" style="display:none"></form></div>');
 assert.equal(d.window.__phAccessBridge.open(),'unavailable');
 const wrong=page('<button>LOGIN</button>','https://example.test');assert.equal(wrong.window.__phAccessBridge,undefined);
});

test('official lazy template can be activated without rendering or submitting it',()=>{
 const d=page('<button data-toggle="modal" data-target="#loginModal">LOGIN</button><div id="loginModal" role="dialog"><form id="formLogin" name="login"><script id="loginFormTemplate1" type="text/x-handlebars-template">template</script></form></div>');
 let clicked=0;d.window.document.querySelector('button').onclick=()=>clicked++;
 assert.equal(d.window.__phAccessBridge.open(),'requested');
 assert.equal(clicked,1);assert.equal(d.window.document.querySelector('input'),null);
});
