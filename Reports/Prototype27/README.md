# Matched 3D board scale and a quieter floor

The 3D board camera now derives its framing from the same normalized scale used by Classic and 2D instead of a fixed conservative distance. Resting vials therefore occupy approximately the same visual height in all three presentations across four through ten vials, portrait and landscape. A projection lens shift also keeps their common floor on the same screen baseline as the planar modes without changing the proven lift, pour or return paths.

The large 3D board floor ellipse has been removed. Local contact shadows remain, so vessels still feel grounded without an extra enclosing line. The smaller orientation ellipse in the standalone two-vessel pour study is intentionally retained.

![Classic scale reference](classic-scale-reference.png)

![3D Fluid scale reference without the floor ellipse](fluid-scale-reference.png)

## Verification

- `Scripts/validate_scale_parity.sh` passes for 4, 6, 8 and 10 vials at six portrait/landscape aspect ratios. The maximum normalized height difference from the planar reference is 15.1%, and the common-floor baseline differs by less than 0.7% of view height.
- `Scripts/validate_complexity.sh` passes all 16 model solutions and every 3D/2D move in Five Streams, Tall Order, Sixfold and Valve Circuit with the original collision-safe motion geometry.
- `Scripts/validate_overlap.sh` passes all 18 Classic, 2D and 3D cap-crossing, near-full, crossing, shared-receiver and return-crossing cases with zero vessel penetration, clipping or spatial clipping.

The camera regression measures resting board scale. The renderer continues to reserve enough motion space for the existing authored pours rather than compressing or rerouting them solely to keep every lifted tall vial inside an unusually wide diagnostic crop.
