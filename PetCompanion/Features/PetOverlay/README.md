# Pet placeholder asset contract

Pet artwork uses the name `<species>-<state>`. The supported species identifiers are `otter`, `cat`, `dog`, and `redpanda`; the initial state is `idle`. The asset catalog therefore contains `otter-idle`, `cat-idle`, `dog-idle`, and `redpanda-idle`.

Each asset renders as a 144 × 144-point image at the bottom center of the fixed 320 × 260-point overlay panel. Drop replacement PNGs into the matching `.imageset` at 1× (144 × 144 px), 2× (288 × 288 px), and 3× (432 × 432 px). Keep transparency around the pet; do not bake in the speech bubble or panel background.

Future reaction artwork follows the same convention, such as `otter-happy`, `cat-excited`, `dog-dragged`, and `redpanda-reminding`. Until those states have dedicated artwork, each species' idle asset is its placeholder.
