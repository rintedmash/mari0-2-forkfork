set -euo pipefail
if [[ -n "${GITHUB_WORKSPACE:-}" ]]; then
  cd "$GITHUB_WORKSPACE"
else
  cd "$(dirname "${BASH_SOURCE[0]}")/../.."
fi
mkdir -p dist/android/smoke
adb install -r dist/android/mari0-2-debug.apk
adb shell am force-stop com.wokitron.mari02
adb logcat -c
adb shell am start -n com.wokitron.mari02/org.love2d.android.GameActivity
for attempt in {1..60}; do
  adb logcat -d > dist/android/smoke/wait-log.txt
  if grep -Fq MARI0_2_ERROR dist/android/smoke/wait-log.txt; then
    cat dist/android/smoke/wait-log.txt
    exit 1
  fi
  last_video="$(grep -F 'MARI0_VIDEO_SETTLED' dist/android/smoke/wait-log.txt | tail -n 1 || true)"
  if grep -Fq MARI0_2_STARTUP_COMPLETE dist/android/smoke/wait-log.txt \
     && [[ $last_video =~ window=([0-9]+)x([0-9]+) ]] \
     && (( BASH_REMATCH[1] > BASH_REMATCH[2] )); then
    break
  fi
  sleep 2
done
adb logcat -d > dist/android/smoke/startup-log.txt
grep -Fq MARI0_2_STARTUP_COMPLETE dist/android/smoke/startup-log.txt
grep -Fq MARI0_VIDEO_SETTLED dist/android/smoke/startup-log.txt
sleep 3
adb logcat -d > dist/android/smoke/startup-log.txt
video_line="$(grep -F 'MARI0_VIDEO_SETTLED' dist/android/smoke/startup-log.txt | tail -n 1)"
echo "$video_line"
python - "$video_line" <<'PY'
import re
import sys

line = sys.argv[1]
match = re.search(
    r"MARI0_VIDEO_SETTLED os=(\S+) drawable=(\d+)x(\d+) window=(\d+)x(\d+) "
    r"scale=([\d.]+) logical=(\d+)x(\d+) touchSupported=(\w+) fitToScreen=(\w+)",
    line,
)
assert match, f"MARI0_VIDEO diagnostic missing or malformed: {line}"
os_name, dw, dh, ww, wh, scale, lw, lh, touch_supported, fit = match.groups()
dw, dh, ww, wh, lw, lh = (int(value) for value in (dw, dh, ww, wh, lw, lh))
scale = float(scale)
assert os_name == "Android", f"unexpected OS: {os_name}"
assert touch_supported == "true", "touch controls are not enabled on Android"
assert fit == "true", "fit-to-screen scaling is not enabled on Android"
expected_scale = min(ww / 400, wh / 224)
assert abs(scale - expected_scale) < 0.01, f"scale {scale} does not fit window {ww}x{wh}"
assert abs(lw - ww / scale) < 1 and abs(lh - wh / scale) < 1, (
    f"logical size {lw}x{lh} does not match window {ww}x{wh} at scale {scale}"
)
assert abs((lw / lh) - (ww / wh)) < 0.02, (
    f"logical aspect {lw}x{lh} does not preserve window aspect {ww}x{wh}; the view will be stretched"
)
print(f"MARI0_VIDEO_SETTLED ok: window {ww}x{wh}, scale {scale}, logical {lw}x{lh}")
PY
sleep 3
adb exec-out screencap -p > dist/android/smoke/menu.png
adb shell pidof com.wokitron.mari02 | tr -d '\r' | grep -q .
read -r start_x start_y left_x left_y jump_x jump_y portal1_x portal1_y portal2_x portal2_y runlock_x runlock_y close_x close_y use_x use_y unit_pixels <<< "$(python - <<'PY'
from PIL import Image
image = Image.open("dist/android/smoke/menu.png").convert("RGB")
pixels = list(image.resize((80, 36)).getdata())
assert len(set(pixels)) > 32, "Menu screenshot appears blank"
assert sum(max(pixel) > 40 for pixel in pixels) / len(pixels) > 0.08, "Menu screenshot appears blank"
source = image.load()
left, top = image.width, image.height
right = bottom = 0
for y in range(0, image.height, 4):
    for x in range(0, image.width, 4):
        if max(source[x, y]) > 40:
            left = min(left, x)
            top = min(top, y)
            right = max(right, x + 1)
            bottom = max(bottom, y + 1)
viewport_width = right - left
viewport_height = bottom - top
assert viewport_width * viewport_height > image.width * image.height * 0.25, "Could not locate the LÖVE viewport"
unit = min(viewport_width / 400, viewport_height / 224)
start_x, start_y = left + round(viewport_width - 26.5 * unit), top + round(13 * unit)
left_x, left_y = left + round(26 * unit), top + round(174 * unit)
jump_x, jump_y = left + round(viewport_width - 29 * unit), top + round(viewport_height - 40 * unit)
portal1_x, portal1_y = left + round(18.5 * unit), top + round(85.5 * unit)
portal2_x, portal2_y = left + round(18.5 * unit), top + round(113.5 * unit)
runlock_x, runlock_y = left + round(viewport_width - 120.5 * unit), top + round(viewport_height - 17.5 * unit)
close_x, close_y = left + round(18.5 * unit), top + round(141.5 * unit)
use_x, use_y = left + round(viewport_width - 120.5 * unit), top + round(viewport_height - 42.5 * unit)
with open("dist/android/smoke/geometry.txt", "w") as handle:
    handle.write(f"{left} {top} {viewport_width} {viewport_height} {unit}\n")
print(start_x, start_y, left_x, left_y, jump_x, jump_y, portal1_x, portal1_y, portal2_x, portal2_y, runlock_x, runlock_y, close_x, close_y, use_x, use_y, round(unit))
PY
)"
adb shell input tap "$start_x" "$start_y"
sleep 5
adb logcat -d > dist/android/smoke/gameplay-log.txt
grep -Fq MARI0_2_TOUCH_START_OK dist/android/smoke/gameplay-log.txt
adb exec-out screencap -p > dist/android/smoke/gameplay.png
python - <<'PY'
from PIL import Image

left, top, viewport_width, viewport_height, unit = (
    float(value) for value in open("dist/android/smoke/geometry.txt").read().split()
)

image = Image.open("dist/android/smoke/gameplay.png").convert("RGB")
source = image.load()

def button_visible(center_x, center_y, radius, label="button"):
    hits = 0
    x0 = max(0, int(center_x - radius))
    y0 = max(0, int(center_y - radius))
    x1 = min(image.width - 1, int(center_x + radius))
    y1 = min(image.height - 1, int(center_y + radius))
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if min(source[x, y]) > 185:
                hits += 1
                if hits >= 3:
                    return True
    return False

checks = (
    ("up", left + 55 * unit, top + (viewport_height - 79 * unit)),
    ("jump", left + (viewport_width - 29 * unit), top + (viewport_height - 40 * unit)),
    ("run", left + (viewport_width - 83 * unit), top + (viewport_height - 40 * unit)),
)
for name, center_x, center_y in checks:
    assert button_visible(center_x, center_y, 15 * unit), f"{name} touch button is not visible on screen"
print("Touch buttons are visible on screen")
PY
adb shell input swipe "$left_x" "$left_y" "$((left_x + 10 * unit_pixels))" "$left_y" 1200
adb shell input tap "$jump_x" "$jump_y"
sleep 2
adb shell pidof com.wokitron.mari02 | tr -d '\r' | grep -q .
adb shell input tap "$portal1_x" "$portal1_y"
adb shell input tap "$portal2_x" "$portal2_y"
adb shell input tap "$close_x" "$close_y"
adb shell input tap "$use_x" "$use_y"
adb shell input tap "$runlock_x" "$runlock_y"
sleep 1
adb shell pidof com.wokitron.mari02 | tr -d '\r' | grep -q .
adb logcat -d > dist/android/smoke/gameplay-input-log.txt
for input in LEFT JUMP PORTAL1 PORTAL2 CLOSEPORTALS USE RUNLOCK; do
  grep -Fq "MARI0_2_TOUCH_${input}_OK" dist/android/smoke/gameplay-input-log.txt
done
if grep -E 'FATAL EXCEPTION|E/AndroidRuntime|UnsatisfiedLinkError|MARI0_2_ERROR' dist/android/smoke/gameplay-input-log.txt; then
  exit 1
fi
adb exec-out screencap -p > dist/android/smoke/gameplay-input.png
python - <<'PY'
from PIL import Image, ImageChops
menu = Image.open("dist/android/smoke/menu.png").convert("RGB").resize((80, 36))
gameplay = Image.open("dist/android/smoke/gameplay.png").convert("RGB").resize((80, 36))
diff = ImageChops.difference(menu, gameplay)
changed = sum(max(pixel) > 24 for pixel in diff.getdata()) / (80 * 36)
assert changed > 0.02, "Start button did not transition from the menu into gameplay"
image = Image.open("dist/android/smoke/gameplay-input.png").convert("RGB").resize((80, 36))
pixels = list(image.getdata())
assert len(set(pixels)) > 32, "Gameplay screenshot appears blank"
PY