# Publication review

- This is an independent public build tree, not a fork or mirror of private history.
- The new initial commit contains only a generated repository README. Subsequent
  source publication descends only from that clean initial commit.
- Runtime Dart files, iOS project files and the two JS assets are byte-identical
  to the reviewed existing 1.1.1 build 3. No functional app change is introduced.
- Test fixtures have been replaced with synthetic names/labels and metrics.
  No personal league images, screenshots or authenticated page snapshots are included.
- Android, signing folders, provisioning profiles, certificates, environment files,
  generated settings, caches, build outputs, old reports and personal documents
  are excluded. Only app-owned PH icons and standard launch placeholders remain.
- Source/dependency scans check known credential formats, private-key headers,
  forbidden filenames, personal fixture labels, absolute developer paths and PNG
  metadata. Dependency locks refer to public registries, without authenticated URLs.
- Authentication-related words in tests are deliberately fake rejection fixtures,
  not actual credentials. Production reads existing OS cookies only for the official
  user-requested download, without recording them.
- Dependencies are resolved from pinned public pub.dev/npm/CocoaPods lockfiles.
  Flutter embeds dependency license notices; dependency source trees are not vendored.
- No raw browser/plugin/native log is uploaded. Simulator output is limited to
  fixed-category diagnostics, booleans/counts and public unauthenticated screenshots.
- Runner: standard macos-15, manual workflow_dispatch only, single job, no caches,
  35-minute job cap, 3-day artifact retention, contents:read permission only.
- No billing setting, budget, payment method or paid integration is modified.
