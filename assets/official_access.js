// Installs an explicit action; installation itself never clicks or navigates.
(() => {
 if(location.origin!=='https://leghe.fantacalcio.it'||location.pathname!=='/') return false;
 const check=e=>{
  if(!e||!e.isConnected)return 1;
  if(e.disabled||e.getAttribute('aria-disabled')==='true'||e.form)return 3;
  for(let a=e;a;a=a.parentElement){const s=getComputedStyle(a);if(a.hidden||a.inert)return 4;if(s.display==='none')return a===e?5:6;if(s.visibility==='hidden'||s.visibility==='collapse')return a===e?7:8;if(parseFloat(s.opacity)<=0)return a===e?9:10;}
  const r=e.getBoundingClientRect();if(r.width<=0||r.height<=0)return 11;
  if(getComputedStyle(e).pointerEvents==='none')return 12;
  const x=r.left+r.width/2,y=r.top+r.height/2;
  if(x<0||y<0||x>=innerWidth||y>=innerHeight)return 13;
  const hit=document.elementFromPoint(x,y);if(!hit||!(hit===e||e.contains(hit)))return 14;
  return 0;
 };
 const fieldsVisible=dialog=>Array.from(dialog.querySelectorAll('input[type="password"]')).some(e=>check(e)===0);
 window.__phOfficialAccess={async open(){
  const buttons=Array.from(document.querySelectorAll('.showcase .panel-my-leagues button[data-toggle="modal"][data-target="#loginModal"]')).filter(e=>(e.textContent||'').trim()==='LOGIN'&&!e.closest('template'));
  if(!buttons.length)return 1;if(buttons.length!==1)return 2;
  const reason=check(buttons[0]);if(reason)return reason;
  const dialogs=document.querySelectorAll('div#loginModal[role="dialog"]');if(dialogs.length!==1)return 15;
  if(typeof window.jQuery?.fn?.modal!=='function')return 16;
  buttons[0].click();
  await new Promise(r=>setTimeout(r,800));
  return fieldsVisible(dialogs[0])?0:17;
 }};return true;
})();
