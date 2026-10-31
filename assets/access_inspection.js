// Read-only observation. No clicks, field values, source text, storage or navigation.
(() => {
 if (location.origin !== 'https://leghe.fantacalcio.it') return JSON.stringify({command:'origin_rejected'});
 const visible=e=>{if(!e)return false;const r=e.getBoundingClientRect(),s=getComputedStyle(e);return r.width>0&&r.height>0&&s.display!=='none'&&s.visibility!=='hidden';};
 const state=e=>!e?'absent':visible(e)?'visible':'hidden';
 const controls=Array.from(document.querySelectorAll('button[data-toggle="modal"][data-target]')).filter(b=>/^(login|accedi)$/i.test((b.getAttribute('aria-label')||b.textContent||'').trim()));
 const shown=controls.filter(visible), enabled=shown.filter(b=>!b.disabled&&!b.form&&b.getAttribute('aria-disabled')!=='true');
 const eligible=enabled.filter(b=>{const t=b.getAttribute('data-target');if(!/^#[a-zA-Z][a-zA-Z0-9_-]{0,80}$/.test(t||''))return false;return document.getElementById(t.slice(1))?.getAttribute('role')==='dialog';});
 const dialog=document.querySelector('[role="dialog"]#loginModal');
 const password=dialog?.querySelector('input[type="password"]');
 const username=dialog?.querySelector('input[autocomplete="username"],input[name="username"]');
 const jq=window.jQuery;
 let instance='unknown';
 // jQuery public data getter; no private event registry is inspected.
 if(dialog&&typeof jq==='function'&&typeof jq.fn?.modal==='function') instance=jq(dialog).data('bs.modal')?'present':'absent';
 return JSON.stringify({command:'executed',trigger:!controls.length?'absent_active_dom':!shown.length?'hidden':!enabled.length?'excluded':eligible.length>1?'ambiguous':eligible.length===1?'recognized':'excluded',dialog:state(dialog),password:state(password),username:state(username),passwordEnabled:!password?'absent':password.disabled||password.readOnly?'disabled':'enabled',usernameEnabled:!username?'absent':username.disabled||username.readOnly?'disabled':'enabled',plugin:typeof jq?.fn?.modal==='function'?'present':'absent',modalInstance:instance,handler:'unknown',initialization:'unknown',ready:['loading','interactive','complete'].includes(document.readyState)?document.readyState:'unknown'});
})();
