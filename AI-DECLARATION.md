---
version: "0.1.2"
level: auto
processes:
  design: auto
  implementation: auto
  testing: auto
  documentation: auto
  deployment: auto
  review: auto
components:
  .wiki.git: assist
  class/Actor.lua: auto
  components/smb3/animation.lua: copilot
  .github/workflows/build.yml: auto  .github/scripts/android-smoke-test.sh: auto
  .github/android/res/drawable/love.png: auto
  .github/android/res/values/colors.xml: auto
  .gitignore: auto
  makelove.toml: auto
  README.md: auto
  conf.lua: auto
  lib/TouchControls.lua: auto
  lib/controls3.lua: auto
  main.lua: auto
  state/Game.lua: auto
  test/test_touchcontrols.lua: auto  test/test_controls3.lua: auto
  test/test_actor_destroy.lua: auto
---

This format is based on [AI-DECLARATION.md](https://ai-declaration.md/en/0.1.2).

## Notes

- The free tier of Github Copilot was used
- Copilot provided the first insights into the codebase
- Copilot generated the actor destruction function
- Copilot fixed a crash when the somersault animation of the player did not exist
- Earlier Copilot output was reviewed by a human
- Zo Computer AI authored the mobile controls, tests, Android build workflow, and related documentation in this update
- Zo Computer AI reviewed the Copilot-attributed actor and somersault changes; repeated actor destruction now returns without repeating cleanup
- All other assets are human-made
