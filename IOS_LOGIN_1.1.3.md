# 1.1.3 build 6 — official modal login

Recognize the official formLogin/loginFormTemplate1 lazy template as well as rendered password fields. Only activate the existing visible, unique LOGIN/ACCEDI modal button; never compile templates, submit forms, fill credentials or generate authentication URLs. Unknown layouts fail closed. No Safari session transfer is assumed.

The iPhone trace identifies a web link to the exact known /login or /login/ path returning main-frame 404. Presence of a password field alone (login_form_observed) does not prove visibility or successful login.

The iOS regression no longer deliberately clicks the failing login anchor. It exercises the app menu modal action and requires a visible enabled password field, username control, preserved WebView, no error panel and no official_login navigation. No credentials are submitted. Final remote outcome must be read from the produced evidence; compilation is not login verification.

Local validation: 26 Flutter tests, 12 JavaScript tests passed; analyzer clean. Public publication contains only reviewed application code/tests/build files; no phone diagnostic report or private history is copied.
