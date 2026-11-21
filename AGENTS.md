# ForeverQoL development and releases

- Target the WoW Forever client (Interface 16001). Verify APIs against the Forever client UI source, not legacy Classic assumptions.
- Keep the checked-in TOC version at the latest public version during development; before the first release use `0.1.0` as the initial version baseline.
- After every addon change, run `tools/test.ps1` and deploy with `tools/deploy.ps1`. Local installation is part of completing a change.
- Each deployment increments a local identifier such as `0.1.0-dev.1`. Keep it only in the installed addon; never include it in release packages. Report the exact verified deployment identifier. `/fql` must display the loaded build after `/reload`.
- Publish only when the owner explicitly requests a release, through the manual GitHub Actions workflow. Commits, pushes and local installs do not trigger releases.
- Bump the public version once per release based on changes since the previous public release: patch for fixes only, minor for new features. Development deployments do not consume public versions.
- Preserve native Blizzard styling and keep modules independent as quality-of-life features grow.
- Bank controls must fit the existing header. Do not resize or reanchor Blizzard's bank, item panel, search, artwork or other native controls to make room.
