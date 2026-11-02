# Performance Opportunity Register

Record measured concerns only. Linux software-renderer numbers do **not** represent Windows GPU performance.

| # | Area | Evidence | Likely cause | Risk | Possible improvement | Status |
|---|---|---|---|---|---|---|
| 1 | Homestead rendering (iteration 001) | Two instances, 1600×900, Mesa llvmpipe (CPU rendering), 4 shared cores: 21–25 fps each; ~1000 nodes per instance | Software rasterising ~400 alpha-blended sprites + full-screen overlay on CPU | Low on GPU hardware (unmeasured) | Measure on Windows first. If needed: merge scatter tufts into fewer textures, disable sway on distant tufts | **Windows measurement pending** |
| 2 | Occlusion checks | ~30 `Prop`s with `occlude` run a cheap rectangle test per frame | By design | Very low | Only revisit if prop counts grow by an order of magnitude | Observed, no action |
| 3 | Host simulation with a horde (iterations 006–009) | `tools/mp_test.py perf_multi`: two connected processes on Linux, horde event + 2 extra groups = up to 27 zombies around both players. Host `Simulation.advance` cost peaked at **0.68 ms per frame**; the client mirrored all 27 zombies. Integrated slice run (single player): under 8 ms at all times (checked) | A* path budget (3/tick), per-tick nav dynamic-block recompute per region | Low | If hordes grow: cache dynamic blocked cells per region per tick (already per tick), cap horde size (configurable: `siege_size`, `max_active`) | Measured; no action |
| 4 | Snapshot traffic | Zombie and survivor rows are sent unreliably at 10 Hz (all regions); objects/meta are sent only on change | By design | Low at 2–8 players | Filter zombie rows by the receiving player's region if player counts grow | Observed, no action |
