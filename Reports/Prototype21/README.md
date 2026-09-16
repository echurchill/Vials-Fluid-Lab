# Smooth 3D glass edges

The brighter Prototype20 glass made the single-sample stair-stepping easy to see on the iPad. The 3D board now uses 4x multisample antialiasing (MSAA) for glass geometry, falling back to 2x or 1x only if the GPU does not support the higher count. The rim, side and foot colors and widths are unchanged; smoothing does not undo the stronger outline.

Glass and its background-copy pipeline use matching sample counts. Each glass batch resolves into the existing single-sample scene texture; multisample depth is retained across overlapping batches so their depth ordering uses matching coverage samples. The final screen copy needs no depth attachment. Fluid reconstruction, the render-resolution cap and the particle solver are unchanged. This adds multisample color/depth storage and resolve work, without a separate antialiasing shader pass.

This follows Apple's [MSAA rendering guidance](https://developer.apple.com/documentation/metal/improving-edge-rendering-quality-with-multisample-antialiasing-msaa). Shader-only brightness changes cannot supply geometric edge coverage; the glass pass needs antialiasing where its triangles meet the background.

## Visual checks

Confluence matches the user's reported puzzle: [landscape before](landscape-before.png), [landscape after](landscape-after.png), [portrait before](portrait-before.png) and [portrait after](portrait-after.png). Both [left](left-after.png) and [right](right-after.png) orbit limits were rendered. The empty-vial silhouettes and mouth rims show smoother coverage while keeping a visible neutral outline. The scene is still reconstructed at a reduced resolution, so this does not promise native-screen-resolution sharpness.

The native [overlap checks](overlap-summary.json) complete all 30 transfers in Classic, 2D and 3D, with no sampled 3D intersections or 2D/3D clipping. Inspect [shared-left landscape](fluid-shared-left-140-landscape.png) and [shared-right portrait](fluid-shared-right-140-portrait.png) captures. Geometry checks are finite samples, and Classic's placeholder counters are not quantitative geometry validation. GPU command completion is also checked in all paired fixtures.

## Measured Mac rendering cost

The comparison compiles the previous renderer from `bbe76cc` and the new renderer into one process, using the same current shader library and fixed Confluence state. Forty warmed samples per version per fixture alternate order. No simulation advancement, app UI or compositor is included. These are Apple M4 Mac GPU rendering times, not iPad frame rates or battery estimates. Orientation and orbit changes reuse the same renderers to exercise resource resizing.

| View | Before median ms | After median ms | Median difference ms | Before / after p95 ms |
| --- | ---: | ---: | ---: | ---: |
| landscape | 0.945 | 0.970 | +0.025 | 2.012 / 2.123 |
| portrait | 0.728 | 0.756 | +0.029 | 1.341 / 1.695 |
| left | 0.781 | 0.940 | +0.159 | 1.682 / 1.356 |
| right | 0.810 | 1.034 | +0.224 | 1.332 / 1.932 |

The added median cost in this sample ranges from 0.025 to 0.224 ms. Tail times vary more, with some p95 values increasing and one decreasing. This supports a small rendering-cost increase on this Mac workload, not a guarantee of unchanged device frame pacing. [Raw summary](summary.json).

## Build and device status

macOS Release and signed iOS Release builds pass. Device installation/checks are pending the user's reply about iPad availability. No iPad session was interrupted during this change. Prior Prototype20 USB measurements describe the previous single-sample renderer and are not measurements of this update. The Mac was kept awake with `caffeinate -di` during validation.

## Reproduction

```sh
bash Scripts/validate_glass_antialiasing.sh path/to/default.metallib build/antialiasing/paired
bash Scripts/validate_overlap.sh path/to/default.metallib build/antialiasing/overlap
```

The inherited solver patch and completed-cap ordering issue remain separate follow-ups.
