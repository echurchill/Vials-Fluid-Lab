# Prototype 59 — simulator-compatible Metal dispatch

## Outcome

The iPhone 17 Pro Max simulator now launches and renders the game normally in 3D Fluid.

The simulator was not exposing a phone-layout or saved-game problem. Xcode had stopped the process on Metal's `Dispatch Threads with Non-Uniform Threadgroup Size is not supported on this device` assertion before SwiftUI could present its first frame. The iOS 27 simulator's Metal device rejects partial compute threadgroups, while the physical iPhone accepts them.

Both the full-board and older standalone 3D renderers now submit rounded whole threadgroups. Their compute shaders already return immediately for grid coordinates beyond the particle count or texture dimensions, so the added edge threads are safe and do not alter rendered results. This also removes the same compatibility assumption from the 1D particle kernels instead of fixing only the first 2D smoothing pass that asserted.

## Validation

- Reproduced the white screen on the booted iOS 27 iPhone 17 Pro Max simulator and captured the Metal validation assertion in Xcode.
- Built, installed and launched the corrected app on that same simulator while preserving its data.
- Visually confirmed that the compact phone controls, four-vial board and 3D liquid render normally.
- Confirmed that no `dispatchThreads` call remains in the Lab renderers.
- iPhone Simulator, macOS and signed physical-iOS Debug builds passed.
- Static vessel presentation checks passed, including Course 45, keyed valves and the visible 3D valve-lid regression.
- All 18 cross-lab/presentation concurrency cases plus density, Discovery and machine-exclusivity checks passed.
