# PlantHead Fanta — iOS build

Minimal reviewed build tree for **1.1.2 (4)**, bundle `it.planthead.fanta`.

Only the iOS project, Flutter runtime sources, two JavaScript assets, dependency
lockfiles and tests are included. No original Git history, authenticated data,
private screenshots, signing keys or credentials are included.

Open Actions → iOS 1.1.2 build 4 → Run workflow. Only manual dispatch is enabled.
The workflow uses the standard `macos-15` public runner, no certificates and no
paid services. It runs Flutter and JavaScript tests, compiles unsigned ARM64,
validates the IPA and attempts a real WKWebView login-page rendering test.
No credentials are entered and no login is submitted. Simulator failure does
not invalidate a separately verified device IPA; read the result JSON/screenshots.

Import the IPA into Feather and sign using your own valid certificate/profile.
The IPA is not installable until signed. The app is independent of Fantacalcio.

See PUBLICATION_REVIEW.md for the publication scope and privacy review.


## 1.1.2 — main-frame 404 investigation

See IOS_404_REVIEW.md. The diagnostic export now separates known home/login paths,
other official paths, navigation type, native server redirects and popup frames,
without retaining URLs, query parameters, tokens or page content.
A user-invoked recovery opens only an existing login dialog through the site's
own unambiguous button. It does not rewrite /login or submit credentials.
Read the actual simulator results before treating this as a verified login fix.
