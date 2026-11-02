# Performance Opportunity Register

Record measured concerns only. Linux software-renderer numbers do **not** represent Windows GPU performance.

| # | Area | Evidence | Likely cause | Risk | Possible improvement | Status |
|---|---|---|---|---|---|---|
| 1 | Homestead rendering (iteration 001) | Two instances, 1600×900, Mesa llvmpipe (CPU rendering), 4 shared cores: 21–25 fps each; ~1000 nodes per instance | Software rasterising ~400 alpha-blended sprites + full-screen overlay on CPU | Low on GPU hardware (unmeasured) | Measure on Windows first. If needed: merge scatter tufts into fewer textures, disable sway on distant tufts | **Windows measurement pending** |
| 2 | Occlusion checks | ~30 `Prop`s with `occlude` run a cheap rectangle test per frame | By design | Very low | Only revisit if prop counts grow by an order of magnitude | Observed, no action |
