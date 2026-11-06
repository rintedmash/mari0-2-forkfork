# Mari0 2

[![AI-DECLARATION: auto](https://img.shields.io/badge/䷼%20AI--DECLARATION-auto-ede9fe?labelColor=ede9fe)](https://ai-declaration.md)

<img width="400" height="224" alt="Promotional screenshot of the level editor showing 27 entities" src="https://github.com/user-attachments/assets/c42a7464-a82e-4dc8-9c40-007574e6eff0" />

This fork aims to expand the original prototype of Mari0 2.

Currently, the first world of Super Mario Bros and the level editor are working. However, the software is still in the iteration phase. Do not use it for production yet.

- Download the latest release [here](https://github.com/BrownieO/mari0-2/releases)
- Check the [wiki](https://github.com/BrownieO/mari0-2/wiki) to start contibuting
- External tools for content creation are available [here](https://github.com/BrownieO/mari0-2-utilities)
- Read the AI declaration [here](AI-DECLARATION.md). AI declaration is mandatory.

Developed for LÖVE 11.5

## Android

Touch controls appear only on touchscreen devices and follow Mari0 GE’s layout: a left-side directional pad, **A** to jump, **B** to run, a run-lock toggle, **1/2** to fire portals toward the last touched aim point, **R** to close portals, **U** to use, and **Start** to begin or return to the menu. The desktop input-visualization overlay stays desktop-only. The [GitHub Actions workflow](https://github.com/rintedmash/mari0-2-forkfork/actions/workflows/build.yml) packages the game with `makelove` and passes the `.love` archive through the Marketplace action’s `love-package` input, which extracts it into LÖVE’s embedded game-asset directory. The earlier APK stored the archive as `assets/game.love`; the Android template did not load it, so it opened only the LÖVE runtime. CI now checks the embedded game files, then installs, launches, and exercises the APK in an Android emulator. The APK is for testing, not a Play Store release.

## Credits

- Nintendo - Super Mario assets
- Hummer Team - Super Mario World music
- Jonathan Aldrich - Super Mario physics breakdown
- Maurice Guégan - Everything not listed somewhere else
- Hans Cárdenas - Sprites, title logo, testing
- GlowingUmbreon - Fixes
- Technochips - Fixes
- BrownieO - Wiki, additions, utilities, music
- awesomezack - P-Balloon sprites
- Alesan99 - Circle movement code
- Lu9 - Bonus music arrangement
- Britdan - Research on the physics library
