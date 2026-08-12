#!/bin/bash
# Generates placeholder pet frame imagesets from the single existing idle art.
#
# These are NOT final animation. PetOverlayView renders with .scaledToFit()
# inside a fixed frame, so a slightly smaller PNG reads as gentle breathing.
# That proves the frame pipeline; real art replaces these imagesets by name
# with no code change.
#
# sips cannot pad transparently (--padColor is RGB with no alpha), so scale is
# the only transform available that keeps the pet's transparent background.
set -euo pipefail

ASSETS="$(dirname "$0")/../PetCompanion/Resources/Assets.xcassets"
SOURCE="$ASSETS/redpanda-idle.imageset"

# mood:scale ramp, as percentages of the source size
FRAMES="idle:100,98,96,98 happy:100,108,104 excited:100,110,100,110 sleepy:100,97 reminding:100,104,96"

for entry in $FRAMES; do
  mood="${entry%%:*}"
  scales="${entry#*:}"
  index=1
  IFS=',' read -ra ramp <<< "$scales"
  for pct in "${ramp[@]}"; do
    name=$(printf "redpanda-%s-%02d" "$mood" "$index")
    dir="$ASSETS/$name.imageset"
    mkdir -p "$dir"
    for scale in 1 2 3; do
      case $scale in
        1) suffix=""; base=144 ;;
        2) suffix="@2x"; base=288 ;;
        3) suffix="@3x"; base=432 ;;
      esac
      px=$(( base * pct / 100 ))
      sips -s format png --resampleHeightWidth "$px" "$px" \
        "$SOURCE/redpanda-idle${suffix}.png" \
        --out "$dir/${name}${suffix}.png" >/dev/null
    done
    cat > "$dir/Contents.json" <<JSON
{
  "images" : [
    { "filename" : "${name}.png", "idiom" : "universal", "scale" : "1x" },
    { "filename" : "${name}@2x.png", "idiom" : "universal", "scale" : "2x" },
    { "filename" : "${name}@3x.png", "idiom" : "universal", "scale" : "3x" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
JSON
    index=$(( index + 1 ))
  done
done

echo "Generated placeholder frames."
