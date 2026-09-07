import SwiftUI

struct FluidSegment: View {
    let fluid: Fluid
    let seed: Int
    let unitCount: Int
    var showsSurface = true
    var showsBottomDepth = true

    var body: some View {
        let material = fluid.material

        Rectangle()
            .fill(
                LinearGradient(
                    colors: fillColors(for: material),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(alignment: .top) {
                if showsSurface {
                    UnevenWave(amplitude: material.waveAmplitude, phase: CGFloat(seed) * 0.55)
                        .fill(waveColor(for: material))
                        .frame(height: 10 + CGFloat(min(unitCount, 3)) * 1.5)
                }
            }
            .overlay(alignment: .top) {
                if showsSurface {
                    Capsule()
                        .fill(meniscusColor(for: material))
                        .frame(height: max(2, material.waveAmplitude * 0.85))
                        .blur(radius: material.kind == .clear ? 1.2 : 0.6)
                        .padding(.horizontal, 6)
                        .offset(y: 1)
                }
            }
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(.white.opacity(sideShineOpacity(for: material)))
                    .frame(width: 9)
                    .blur(radius: 4)
                    .padding(.vertical, 2)
            }
            .overlay(alignment: .trailing) {
                Rectangle()
                    .fill(.black.opacity(edgeShadeOpacity(for: material)))
                    .frame(width: 10)
                    .blur(radius: 5)
                    .padding(.vertical, 1)
            }
            .overlay {
                MaterialTextureField(fluid: fluid, seed: seed, density: unitCount)
                    .padding(texturePadding(for: material))
            }
            .overlay {
                if unitCount > 1 {
                    ContinuousMaterialSheen(fluid: fluid, seed: seed)
                        .opacity(mergedSheenOpacity(for: material))
                }
            }
            .overlay {
                if showsBottomDepth {
                    LinearGradient(
                        colors: [.black.opacity(0.00), .black.opacity(shadowOpacity(for: material))],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .blendMode(.multiply)
                }
            }
            .clipped()
    }

    private func fillColors(for material: FluidMaterial) -> [Color] {
        switch material.kind {
        case .clear:
            [fluid.shine.opacity(0.86), fluid.color.opacity(0.86), fluid.color.opacity(0.72)]
        case .fizzy:
            [fluid.shine, fluid.color, fluid.color.opacity(0.90)]
        case .sparkling:
            [fluid.shine, fluid.color.opacity(0.96), fluid.color.opacity(0.82)]
        case .creamy:
            [fluid.shine.opacity(0.94), fluid.color.opacity(0.96), fluid.color.opacity(0.92)]
        case .dense:
            [fluid.shine.opacity(0.62), fluid.color.opacity(0.96), fluid.color.opacity(0.86)]
        case .glowing:
            [fluid.shine, fluid.color, fluid.color.opacity(0.82)]
        case .iridescent:
            [fluid.shine, fluid.color.opacity(0.92), Color.white.opacity(0.22), fluid.color.opacity(0.82)]
        }
    }

    private func waveColor(for material: FluidMaterial) -> Color {
        switch material.kind {
        case .dense:
            .black.opacity(0.13)
        case .creamy:
            .white.opacity(0.20)
        case .glowing:
            fluid.shine.opacity(0.24)
        default:
            .white.opacity(0.16)
        }
    }

    private func meniscusColor(for material: FluidMaterial) -> Color {
        switch material.kind {
        case .clear, .iridescent:
            .white.opacity(0.24)
        case .creamy:
            fluid.shine.opacity(0.30)
        case .dense:
            .black.opacity(0.12)
        case .glowing:
            fluid.shine.opacity(0.34)
        default:
            .white.opacity(0.18)
        }
    }

    private func sideShineOpacity(for material: FluidMaterial) -> Double {
        switch material.kind {
        case .clear, .iridescent:
            0.22
        case .creamy:
            0.12
        case .dense:
            0.06
        default:
            0.15
        }
    }

    private func edgeShadeOpacity(for material: FluidMaterial) -> Double {
        switch material.kind {
        case .clear:
            0.05
        case .creamy:
            0.08
        case .dense:
            0.18
        default:
            0.11
        }
    }

    private func shadowOpacity(for material: FluidMaterial) -> Double {
        switch material.kind {
        case .dense:
            0.20
        case .creamy:
            0.08
        default:
            0.12
        }
    }

    private func texturePadding(for material: FluidMaterial) -> EdgeInsets {
        switch material.kind {
        case .dense:
            EdgeInsets(top: 6, leading: 7, bottom: 6, trailing: 7)
        case .creamy:
            EdgeInsets(top: 4, leading: 5, bottom: 4, trailing: 5)
        default:
            EdgeInsets(top: 3, leading: 5, bottom: 3, trailing: 5)
        }
    }

    private func mergedSheenOpacity(for material: FluidMaterial) -> Double {
        switch material.kind {
        case .clear, .iridescent:
            0.46
        case .glowing:
            0.34
        case .creamy:
            0.24
        case .dense:
            0.12
        default:
            0.20
        }
    }
}

private struct ContinuousMaterialSheen: View {
    let fluid: Fluid
    let seed: Int

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [
                        .white.opacity(0.00),
                        fluid.shine.opacity(0.18),
                        .white.opacity(0.00)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(width: proxy.size.width * 1.2, height: proxy.size.height * 1.2)
                .offset(x: -proxy.size.width * 0.1, y: -proxy.size.height * 0.08)

                Capsule()
                    .fill(.white.opacity(0.16))
                    .frame(width: proxy.size.width * 0.38, height: 2)
                    .rotationEffect(.degrees(seed.isMultiple(of: 2) ? -8 : 7))
                    .position(x: proxy.size.width * 0.48, y: proxy.size.height * 0.38)
            }
        }
        .blendMode(.screen)
    }
}
