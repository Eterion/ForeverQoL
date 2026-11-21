# ForeverQoL development and releases

- Target the WoW Forever client (Interface 16001). Verify APIs against the Forever client UI source, not legacy Classic assumptions.
- Keep the checked-in TOC version at the latest public version during development; before the first release use `0.1.0` as the initial version baseline.
- After every addon change, run `tools/test.ps1` and deploy with `tools/deploy.ps1`. Local installation is part of completing a change.
- Each deployment increments a local identifier such as `0.1.0-dev.1`. Keep it only in the installed addon; never include it in release packages. Report the exact verified deployment identifier. `/fql` must display the loaded build after `/reload`.
- Publish only when the owner explicitly requests a release, through the manual GitHub Actions workflow. Commits, pushes and local installs do not trigger releases.
- Bump the public version once per release based on changes since the previous public release: patch for fixes only, minor for new features. Development deployments do not consume public versions.
- Preserve native Blizzard styling and keep modules independent as quality-of-life features grow.
- Bank controls occupy their own unframed row inside the bank beneath its title, above search. The row has no added border or background. Use a plain layout container with only top anchors, not NineSlicePanelTemplate (which inherits full-parent anchors and an elevated frame level). The owner authorized moving search and contents down together to make room. Keep the visible filter dropdown left of labeled Deposit/Withdraw buttons. Preserve the native body's dimensions and anchor its background to that body, rather than stretching its art over the added header. Derive the outer height from Blizzard's current body height so page changes and repeated refreshes cannot accumulate extra height.
