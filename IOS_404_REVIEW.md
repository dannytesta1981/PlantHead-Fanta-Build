# 1.1.2 build 5 — evidence and limits

## Evidence before changing code

On-device 1.1.1 diagnostics show successful creation and a readable initial DOM,
followed by main-frame HTTP 404 on later navigation. The old export did not retain
route categories or navigation types, so it cannot identify which path caused
those device responses. No private diagnostic file or authenticated data is
included in this public repository.

Public unauthenticated inspection of the existing official home returned HTTP
200. It contained an anchor to the already-known /login path, which returned
HTTP 404 from this environment. It also contained a LOGIN button with Bootstrap
modal attributes targeting an existing dialog containing the login form. The
public auth script binds to that dialog. This is evidence for a site-supplied
broken link in this environment, not proof of the exact path on the user's phone
or a universal service outage. No guessed path or API is introduced.

## Motivated changes

- HTTP 404 stays an HTTP error, with explicit main-page recovery text. It is no
  longer recorded as a generic network failure. Subframe errors remain separate.
- Each main navigation receives an in-memory numeric correlation id. Route
  categories: official_home, official_login, official_other, identity, external,
  blank, blocked or unknown. No URLs, pathname fragments/hashes, query, headers,
  cookies, tokens, form values, account data or raw exception strings are stored.
- Native WebKit server-redirect callbacks are reported explicitly. A client-side
  navigation classified OTHER is not labelled as a redirect without evidence.
  App-issued home/reload/control commands are separate events, not assertions
  that the app generated an unknown site URL. Main and popup journals are distinct.
- Recovery is user invoked: return to the existing official home and activate
  its own unique visible modal button if associated with a password form. No
  fabricated URL, credentials, form submission or change to site authentication.
  Unknown/ambiguous layouts fail visibly and remain fully available in the site UI.
- Popup windowId, opener, request method and OS cookie handling remain unchanged.
  TLS policy and navigation allowlists are unchanged.
- Seeing a login form clears stale native league snapshots; the diagnostic event
  is now login_form_observed. It is not labelled as an OS session/cookie wipe.
- CI disables inherited shell -e around the optional driver result and stores
  response JSON also after assertion failures. Failed integration tests now mark
  the job failed while always() preserves the independently verified IPA.

## Actual iOS validation

The integration test follows only the login anchor actually present in the live
home DOM, captures its route/error, then exercises the user-visible home-dialog
recovery and checks a visible password field, no Flutter error panel, screenshot
and controller preservation on reopen. It never enters credentials or submits
login. A 404 is not assumed: if absent it is reported as not reproduced.

Actual run, screenshots and diagnostic results must be read from the generated
artifact. A compiled IPA or a process start is not evidence that access works.
The exact cause of any device-only path remains unverified until new route-
classified on-device diagnostics or the matching simulator sequence identify it.
