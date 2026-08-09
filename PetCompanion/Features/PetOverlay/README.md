# Pet placeholder asset contract

`PetOverlayView` renders a 144 × 144-point image named `redpanda-idle` at the bottom center of its fixed 320 × 260-point panel.

Drop replacement PNGs into the matching `.imageset` at 1× (144 × 144 px), 2× (288 × 288 px), and 3× (432 × 432 px). Keep transparency around the pet; do not bake in the speech bubble or panel background. Future reaction states use the same `redpanda-<state>` naming convention, such as `redpanda-happy`, `redpanda-excited`, `redpanda-dragged`, and `redpanda-reminding`.
