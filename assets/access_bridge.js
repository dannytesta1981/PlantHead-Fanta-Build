// Opens only an existing, unambiguous login dialog through the site's own button.
// No form submission, URL generation, field values, cookies, storage or network.
(() => {
  if (location.origin !== 'https://leghe.fantacalcio.it') return false;
  const visible = e => {
    if (!e) return false;
    const r = e.getBoundingClientRect(), s = getComputedStyle(e);
    return r.width > 0 && r.height > 0 && s.display !== 'none' && s.visibility !== 'hidden';
  };
  const fields = () => Array.from(document.querySelectorAll('input[type="password"]'));
  const candidates = () => Array.from(document.querySelectorAll('button[data-toggle="modal"][data-target]')).filter(b => {
    if (b.form || b.disabled || !visible(b)) return false;
    if (!/^(login|accedi)$/i.test((b.getAttribute('aria-label') || b.textContent || '').trim())) return false;
    const target = b.getAttribute('data-target');
    if (!/^#[a-zA-Z][a-zA-Z0-9_-]{0,80}$/.test(target || '')) return false;
    const dialog = document.getElementById(target.slice(1));
    // The official site may render its fields lazily from its own template.
    // Activate only the existing modal trigger; never render/parse that template.
    return dialog?.getAttribute('role') === 'dialog' &&
      !!dialog.querySelector('form input[type="password"], form#formLogin[name="login"] script#loginFormTemplate1[type="text/x-handlebars-template"]');
  });
  const inspect = () => {
    const all = Array.from(document.querySelectorAll('button[data-toggle="modal"][data-target]'))
      .filter(b => /^(login|accedi)$/i.test((b.getAttribute('aria-label') || b.textContent || '').trim()));
    const dialog = document.querySelector('[role="dialog"]#loginModal');
    // Presence of a plugin is not proof that its handlers or Auth.init ran.
    return {
      command: 'executed',
      trigger: !all.length ? 'absent_active_dom' : all.every(b=>!visible(b)) ? 'hidden' :
        all.every(b=>b.disabled || b.form) ? 'disabled_or_form_owned' : candidates().length===1 ? 'eligible_unique' : 'unmatched_or_ambiguous',
      dialog: !dialog ? 'absent' : visible(dialog) ? 'visible' : 'hidden',
      password: !fields().length ? 'absent' : fields().some(visible) ? 'visible' : 'hidden',
      plugin: typeof window.jQuery?.fn?.modal === 'function' ? 'present' : 'absent',
      handler: 'unknown',
      initialization: 'unknown',
      ready: ['loading','interactive','complete'].includes(document.readyState) ? document.readyState : 'unknown'
    };
  };
  window.__phAccessBridge = {
    inspect,
    probe() { return {passwordVisible: fields().some(visible), dialogTriggers: candidates().length}; },
    open() {
      if (fields().some(visible)) return 'already_visible';
      const buttons = candidates();
      if (buttons.length !== 1) return 'unavailable';
      buttons[0].click(); // Existing Bootstrap/site listener handles the dialog.
      return 'requested';
    }
  };
  return true;
})();
