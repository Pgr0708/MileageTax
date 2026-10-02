//
//  VectorArt.swift
//  MileageTax — Resolution-independent scene art drawn with SwiftUI Canvas.
//  Replaces photo backgrounds from the concept boards: mountain lakes with glowing
//  roads, city skylines, coastal sunsets, and dark route maps.
//

import SwiftUI

// MARK: - Deterministic randomness (same art on every launch)

struct SeededRNG: RandomNumberGenerator {
    var state: UInt64
    init(_ seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        return z ^ (z >> 27)
    }
}

// MARK: - Scenic backdrop

enum SceneStyle {
    case mountainLake   // dusk lake, snowy peaks, cyan road — splash, radar, vault
    case alpineDawn     // brighter sky — onboarding, paywall
    case cityNight      // skyline at night — detects drive, classify
    case coastal        // sunset over sea — track
}

private struct ScenePalette {
    var sky: [Color]
    var glow: Color
    var mountains: [Color]   // far → near
    var snow: Bool
    var ground: Color
    var roadGlow: Color

    static func of(_ s: SceneStyle) -> ScenePalette {
        switch s {
        case .mountainLake:
            return .init(sky: [Color(hex: "#050B17"), Color(hex: "#0F2740"), Color(hex: "#3B5A72"), Color(hex: "#D98A55")],
                         glow: Color(hex: "#FFA963"),
                         mountains: [Color(hex: "#5B7A93"), Color(hex: "#2A4257"), Color(hex: "#13222F")],
                         snow: true, ground: Color(hex: "#060C11"), roadGlow: DS.cyan)
        case .alpineDawn:
            return .init(sky: [Color(hex: "#0B1A2E"), Color(hex: "#24486A"), Color(hex: "#7A97AC"), Color(hex: "#F0B07A")],
                         glow: Color(hex: "#FFC48A"),
                         mountains: [Color(hex: "#7F9AB0"), Color(hex: "#3D5A70"), Color(hex: "#182A38")],
                         snow: true, ground: Color(hex: "#070E14"), roadGlow: DS.cyan)
        case .cityNight:
            return .init(sky: [Color(hex: "#03060D"), Color(hex: "#0B1628"), Color(hex: "#24324A"), Color(hex: "#C46A3A")],
                         glow: Color(hex: "#FF8A4C"),
                         mountains: [Color(hex: "#1C2A3C"), Color(hex: "#111C2A"), Color(hex: "#0A121C")],
                         snow: false, ground: Color(hex: "#05090E"), roadGlow: DS.cyan)
        case .coastal:
            return .init(sky: [Color(hex: "#0C0A22"), Color(hex: "#3A2450"), Color(hex: "#A4506A"), Color(hex: "#FF9A55")],
                         glow: Color(hex: "#FFB066"),
                         mountains: [Color(hex: "#4A3A5E"), Color(hex: "#2A2238"), Color(hex: "#120F1C")],
                         snow: false, ground: Color(hex: "#07070D"), roadGlow: Color(hex: "#FFB347"))
        }
    }
}

/// Full-bleed vector landscape. `horizon` is the fraction of height where sky meets land.
struct ScenicBackdrop: View {
    var style: SceneStyle = .mountainLake
    var horizon: CGFloat = 0.5
    var showRoad = true
    var vignette = true
    var seed: UInt64 = 7
    /// Asset-catalog image to show instead of the drawn scene, once it has been added.
    var photo: String? = nil

    var body: some View {
        Group {
            if let photo, UIImage(named: photo) != nil {
                PhotoFill(name: photo, vignette: vignette)
            } else {
                Canvas(rendersAsynchronously: true) { ctx, size in draw(ctx, size) }
            }
        }
        .background(DS.bg)
        .accessibilityHidden(true)
    }

    private func draw(_ ctx: GraphicsContext, _ size: CGSize) {
        let w = size.width, h = size.height
        let hy = h * horizon
        let p = ScenePalette.of(style)
        var rng = SeededRNG(seed)

        // Sky
        ctx.fill(Path(CGRect(x: 0, y: 0, width: w, height: hy + 2)),
                 with: .linearGradient(Gradient(colors: p.sky), startPoint: .zero, endPoint: CGPoint(x: 0, y: hy)))
        // Stars
        for _ in 0..<90 {
            let x = CGFloat.random(in: 0...w, using: &rng)
            let y = CGFloat.random(in: 0...(hy * 0.45), using: &rng)
            let r = CGFloat.random(in: 0.4...1.3, using: &rng)
            ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                     with: .color(.white.opacity(Double.random(in: 0.25...0.8, using: &rng))))
        }
        // Horizon glow
        ctx.fill(Path(CGRect(x: 0, y: 0, width: w, height: hy)),
                 with: .radialGradient(Gradient(colors: [p.glow.opacity(0.55), p.glow.opacity(0)]),
                                       center: CGPoint(x: w * 0.55, y: hy), startRadius: 0, endRadius: w * 0.75))

        // Mountains (far → near)
        var ranges: [Path] = []
        let heights: [CGFloat] = [0.30, 0.20, 0.11]
        for (i, color) in p.mountains.enumerated() {
            if style == .cityNight && i == 2 { break }
            let path = ridge(w: w, base: hy + 1, peak: h * heights[i] * (style == .cityNight ? 0.45 : 1), rng: &rng)
            ranges.append(path)
            let top = hy - h * heights[i]
            let colors: [Color] = (p.snow && i < 2)
                ? [Color(hex: "#DCE6EE").opacity(i == 0 ? 0.85 : 0.55), color, color]
                : [color.opacity(0.95), color]
            var layer = ctx
            if i == 0 { layer.opacity = 0.9 }
            layer.fill(path, with: .linearGradient(Gradient(colors: colors),
                                                   startPoint: CGPoint(x: 0, y: top), endPoint: CGPoint(x: 0, y: hy)))
            // Atmospheric haze between layers
            ctx.fill(Path(CGRect(x: 0, y: hy - h * 0.06, width: w, height: h * 0.06)),
                     with: .linearGradient(Gradient(colors: [p.glow.opacity(0), p.glow.opacity(0.08)]),
                                           startPoint: CGPoint(x: 0, y: hy - h * 0.06), endPoint: CGPoint(x: 0, y: hy)))
        }

        if style == .cityNight { drawCity(ctx, w: w, hy: hy, h: h, rng: &rng) }

        // Below the horizon
        switch style {
        case .mountainLake, .alpineDawn:
            let waterBottom = hy + h * 0.12
            let water = CGRect(x: 0, y: hy, width: w, height: waterBottom - hy)
            ctx.fill(Path(water), with: .linearGradient(Gradient(colors: [p.glow.opacity(0.45), p.sky[1], p.sky[0]]),
                                                        startPoint: CGPoint(x: 0, y: hy), endPoint: CGPoint(x: 0, y: waterBottom)))
            ctx.drawLayer { l in
                l.clip(to: Path(water))
                l.opacity = 0.35
                let flip = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: 2 * hy)
                for (i, r) in ranges.enumerated() { l.fill(r.applying(flip), with: .color(p.mountains[i])) }
            }
            for _ in 0..<26 { // water shimmer
                let y = CGFloat.random(in: hy...waterBottom, using: &rng)
                let x = CGFloat.random(in: 0...w, using: &rng)
                ctx.fill(Path(CGRect(x: x, y: y, width: CGFloat.random(in: 8...40, using: &rng), height: 0.8)),
                         with: .color(p.glow.opacity(0.35)))
            }
            fillGround(ctx, w: w, h: h, top: waterBottom, color: p.ground, rng: &rng)
            trees(ctx, w: w, baseY: hy + 2, minH: h * 0.008, maxH: h * 0.022, count: 70, color: Color(hex: "#0B161F"), rng: &rng)
            trees(ctx, w: w, baseY: waterBottom + h * 0.02, minH: h * 0.03, maxH: h * 0.08, count: 26,
                  color: Color(hex: "#03080C"), edgesOnly: true, rng: &rng)
            if showRoad { road(ctx, w: w, h: h, from: CGPoint(x: w * 0.68, y: h + 10), c1: CGPoint(x: w * 0.9, y: h * 0.82),
                              c2: CGPoint(x: w * 0.3, y: waterBottom + h * 0.1), to: CGPoint(x: w * 0.46, y: waterBottom + h * 0.015),
                              width: w * 0.42, glow: p.roadGlow) }
        case .cityNight:
            fillGround(ctx, w: w, h: h, top: hy, color: p.ground, rng: &rng, flat: true)
            if showRoad { road(ctx, w: w, h: h, from: CGPoint(x: w * 0.5, y: h + 10), c1: CGPoint(x: w * 0.55, y: h * 0.8),
                              c2: CGPoint(x: w * 0.46, y: hy + h * 0.1), to: CGPoint(x: w * 0.5, y: hy + 2),
                              width: w * 0.9, glow: p.roadGlow) }
        case .coastal:
            // Sea on the right, cliffs on the left
            let sea = CGRect(x: 0, y: hy, width: w, height: h - hy)
            ctx.fill(Path(sea), with: .linearGradient(Gradient(colors: [p.glow.opacity(0.6), p.sky[2].opacity(0.6), p.sky[0]]),
                                                      startPoint: CGPoint(x: 0, y: hy), endPoint: CGPoint(x: 0, y: h)))
            for _ in 0..<40 {
                let y = CGFloat.random(in: hy...(hy + h * 0.25), using: &rng)
                let x = CGFloat.random(in: (w * 0.35)...w, using: &rng)
                ctx.fill(Path(CGRect(x: x, y: y, width: CGFloat.random(in: 10...50, using: &rng), height: 0.9)),
                         with: .color(p.glow.opacity(0.4)))
            }
            var cliff = Path()
            cliff.move(to: CGPoint(x: 0, y: hy - h * 0.02))
            cliff.addCurve(to: CGPoint(x: w * 0.55, y: hy + h * 0.06), control1: CGPoint(x: w * 0.25, y: hy - h * 0.04),
                           control2: CGPoint(x: w * 0.45, y: hy + h * 0.01))
            cliff.addCurve(to: CGPoint(x: w * 1.05, y: h), control1: CGPoint(x: w * 0.75, y: hy + h * 0.15),
                           control2: CGPoint(x: w * 0.85, y: h * 0.8))
            cliff.addLine(to: CGPoint(x: 0, y: h))
            cliff.closeSubpath()
            ctx.fill(cliff, with: .linearGradient(Gradient(colors: [Color(hex: "#1A1426"), p.ground]),
                                                  startPoint: CGPoint(x: 0, y: hy), endPoint: CGPoint(x: 0, y: h)))
            trees(ctx, w: w * 0.5, baseY: hy + h * 0.01, minH: h * 0.01, maxH: h * 0.03, count: 30,
                  color: Color(hex: "#0A0812"), rng: &rng)
            if showRoad { road(ctx, w: w, h: h, from: CGPoint(x: w * 0.35, y: h + 10), c1: CGPoint(x: w * 0.95, y: h * 0.8),
                              c2: CGPoint(x: w * 0.05, y: hy + h * 0.14), to: CGPoint(x: w * 0.5, y: hy + h * 0.05),
                              width: w * 0.55, glow: p.roadGlow) }
        }

        if vignette {
            ctx.fill(Path(CGRect(x: 0, y: 0, width: w, height: h * 0.3)),
                     with: .linearGradient(Gradient(colors: [DS.bg.opacity(0.75), DS.bg.opacity(0)]),
                                           startPoint: .zero, endPoint: CGPoint(x: 0, y: h * 0.3)))
            ctx.fill(Path(CGRect(x: 0, y: h * 0.7, width: w, height: h * 0.3)),
                     with: .linearGradient(Gradient(colors: [DS.bg.opacity(0), DS.bg.opacity(0.85)]),
                                           startPoint: CGPoint(x: 0, y: h * 0.7), endPoint: CGPoint(x: 0, y: h)))
        }
    }

    // Ridged-sine mountain silhouette closed down to `base`.
    private func ridge(w: CGFloat, base: CGFloat, peak: CGFloat, rng: inout SeededRNG) -> Path {
        let f1 = CGFloat.random(in: 4.5...6.5, using: &rng), p1 = CGFloat.random(in: 0...6, using: &rng)
        let f2 = CGFloat.random(in: 10...14, using: &rng), p2 = CGFloat.random(in: 0...6, using: &rng)
        let f3 = CGFloat.random(in: 26...34, using: &rng), p3 = CGFloat.random(in: 0...6, using: &rng)
        var path = Path()
        path.move(to: CGPoint(x: 0, y: base))
        let steps = 160
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let r1 = 1 - abs(sin(t * f1 + p1))
            let r2 = 1 - abs(sin(t * f2 + p2))
            let r3 = 1 - abs(sin(t * f3 + p3))
            let jitter = CGFloat.random(in: -0.025...0.025, using: &rng)
            let n = 0.62 * pow(r1, 1.6) + 0.26 * r2 + 0.09 * r3 + jitter
            path.addLine(to: CGPoint(x: t * w, y: base - peak * (0.2 + 0.8 * n)))
        }
        path.addLine(to: CGPoint(x: w, y: base))
        path.closeSubpath()
        return path
    }

    private func fillGround(_ ctx: GraphicsContext, w: CGFloat, h: CGFloat, top: CGFloat, color: Color,
                            rng: inout SeededRNG, flat: Bool = false) {
        var g = Path()
        g.move(to: CGPoint(x: 0, y: top))
        if !flat {
            for i in 0...24 {
                let x = w * CGFloat(i) / 24
                g.addLine(to: CGPoint(x: x, y: top + CGFloat.random(in: -2...4, using: &rng)))
            }
        } else {
            g.addLine(to: CGPoint(x: w, y: top))
        }
        g.addLine(to: CGPoint(x: w, y: h)); g.addLine(to: CGPoint(x: 0, y: h)); g.closeSubpath()
        ctx.fill(g, with: .linearGradient(Gradient(colors: [color.opacity(0.92), color]),
                                          startPoint: CGPoint(x: 0, y: top), endPoint: CGPoint(x: 0, y: h)))
    }

    private func trees(_ ctx: GraphicsContext, w: CGFloat, baseY: CGFloat, minH: CGFloat, maxH: CGFloat, count: Int,
                       color: Color, edgesOnly: Bool = false, rng: inout SeededRNG) {
        var path = Path()
        for _ in 0..<count {
            var x = CGFloat.random(in: 0...w, using: &rng)
            if edgesOnly { x = Bool.random(using: &rng) ? x * 0.25 : w - x * 0.25 }
            let th = CGFloat.random(in: minH...maxH, using: &rng)
            let tw = th * 0.38
            let y = baseY + (edgesOnly ? CGFloat.random(in: 0...(maxH * 1.4), using: &rng) : 0)
            for tier in 0..<3 { // three stacked triangles = pine
                let ty = y - th * CGFloat(tier) * 0.28
                let s = 1 - CGFloat(tier) * 0.25
                path.move(to: CGPoint(x: x - tw * s / 2, y: ty))
                path.addLine(to: CGPoint(x: x, y: ty - th * 0.5))
                path.addLine(to: CGPoint(x: x + tw * s / 2, y: ty))
                path.closeSubpath()
            }
        }
        ctx.fill(path, with: .color(color))
    }

    private func drawCity(_ ctx: GraphicsContext, w: CGFloat, hy: CGFloat, h: CGFloat, rng: inout SeededRNG) {
        var x: CGFloat = -4
        var windows = Path(), warm = Path()
        while x < w {
            let bw = CGFloat.random(in: w * 0.03...w * 0.075, using: &rng)
            let centerBoost = 1 - min(1, abs(x - w * 0.5) / (w * 0.5))
            let bh = CGFloat.random(in: h * 0.03...h * 0.09, using: &rng) + h * 0.13 * centerBoost * CGFloat.random(in: 0.3...1, using: &rng)
            let rect = CGRect(x: x, y: hy - bh, width: bw, height: bh)
            ctx.fill(Path(rect), with: .linearGradient(Gradient(colors: [Color(hex: "#16243A"), Color(hex: "#0A1220")]),
                                                       startPoint: CGPoint(x: 0, y: rect.minY), endPoint: CGPoint(x: 0, y: hy)))
            if bh > h * 0.12 { // spire
                ctx.fill(Path(CGRect(x: x + bw / 2 - 0.6, y: rect.minY - h * 0.02, width: 1.2, height: h * 0.02)),
                         with: .color(Color(hex: "#16243A")))
            }
            var wy = rect.minY + 4
            while wy < hy - 3 {
                var wx = x + 2
                while wx < x + bw - 3 {
                    if CGFloat.random(in: 0...1, using: &rng) < 0.32 {
                        let r = CGRect(x: wx, y: wy, width: 1.6, height: 2.2)
                        if Bool.random(using: &rng) { warm.addRect(r) } else { windows.addRect(r) }
                    }
                    wx += 4
                }
                wy += 5
            }
            x += bw + CGFloat.random(in: 0...3, using: &rng)
        }
        ctx.fill(warm, with: .color(Color(hex: "#FFC978").opacity(0.75)))
        ctx.fill(windows, with: .color(Color(hex: "#7FE9FF").opacity(0.55)))
    }

    /// Perspective road along a cubic centre-line with glowing edges.
    private func road(_ ctx: GraphicsContext, w: CGFloat, h: CGFloat, from p0: CGPoint, c1: CGPoint, c2: CGPoint,
                      to p3: CGPoint, width: CGFloat, glow: Color) {
        func pt(_ t: CGFloat) -> CGPoint {
            let u = 1 - t
            return CGPoint(x: u*u*u*p0.x + 3*u*u*t*c1.x + 3*u*t*t*c2.x + t*t*t*p3.x,
                           y: u*u*u*p0.y + 3*u*u*t*c1.y + 3*u*t*t*c2.y + t*t*t*p3.y)
        }
        let n = 80
        var left: [CGPoint] = [], right: [CGPoint] = [], center: [CGPoint] = []
        for i in 0...n {
            let t = CGFloat(i) / CGFloat(n)
            let a = pt(max(0, t - 0.005)), b = pt(min(1, t + 0.005))
            let dx = b.x - a.x, dy = b.y - a.y
            let len = max(0.001, sqrt(dx*dx + dy*dy))
            let nx = -dy / len, ny = dx / len
            let half = (width * pow(1 - t, 1.7) + 1.5) / 2
            let c = pt(t)
            center.append(c)
            left.append(CGPoint(x: c.x + nx * half, y: c.y + ny * half))
            right.append(CGPoint(x: c.x - nx * half, y: c.y - ny * half))
        }
        var body = Path()
        body.addLines(left); body.addLines(right.reversed()); body.closeSubpath()
        ctx.fill(body, with: .linearGradient(Gradient(colors: [Color(hex: "#0E151C"), Color(hex: "#05090D")]),
                                             startPoint: p3, endPoint: p0))

        var edges = Path()
        edges.addLines(left); edges.move(to: right[0]); edges.addLines(right)
        var blur = ctx
        blur.addFilter(.blur(radius: 6))
        blur.stroke(edges, with: .color(glow.opacity(0.9)), lineWidth: 5)
        ctx.stroke(edges, with: .color(glow), lineWidth: 1.6)
        ctx.stroke(edges, with: .color(.white.opacity(0.7)), lineWidth: 0.5)

        // Light trail in the near lane + dashed centre line
        let lane = zip(center, right).map { CGPoint(x: ($0.x + $1.x) / 2, y: ($0.y + $1.y) / 2) }
        var trail = Path(); trail.addLines(lane)
        var trailBlur = ctx
        trailBlur.addFilter(.blur(radius: 4))
        trailBlur.stroke(trail, with: .color(glow.opacity(0.55)), lineWidth: 4)
        var mid = Path(); mid.addLines(center)
        ctx.stroke(mid, with: .color(.white.opacity(0.45)), style: StrokeStyle(lineWidth: 1, dash: [10, 12]))
    }
}

// MARK: - Photo slot

/// Fills its frame with an asset image (cropped, never letterboxed) and a slow Ken Burns drift.
struct PhotoFill: View {
    let name: String
    var vignette = true
    @State private var drift = false

    var body: some View {
        GeometryReader { geo in
            Image(name)
                .resizable()
                .scaledToFill()
                .frame(width: geo.size.width, height: geo.size.height)
                .scaleEffect(drift ? 1.08 : 1.0)
                .clipped()
                .overlay {
                    if vignette {
                        LinearGradient(stops: [.init(color: DS.bg.opacity(0.7), location: 0),
                                               .init(color: .clear, location: 0.3),
                                               .init(color: .clear, location: 0.65),
                                               .init(color: DS.bg.opacity(0.9), location: 1)],
                                       startPoint: .top, endPoint: .bottom)
                    }
                }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 18).repeatForever(autoreverses: true)) { drift = true }
        }
    }
}

// MARK: - Route map art (GPS / live map placeholders)

struct MapRouteArt: View {
    var seed: UInt64 = 11
    var routeColor: Color = DS.cyan
    var showPins = true
    var photo: String? = nil

    var body: some View {
        if let photo, UIImage(named: photo) != nil {
            PhotoFill(name: photo, vignette: false)
        } else {
            canvas
        }
    }

    private var canvas: some View {
        Canvas(rendersAsynchronously: true) { ctx, size in
            let w = size.width, h = size.height
            var rng = SeededRNG(seed)
            ctx.fill(Path(CGRect(origin: .zero, size: size)),
                     with: .linearGradient(Gradient(colors: [Color(hex: "#07121A"), Color(hex: "#0A1A24")]),
                                           startPoint: .zero, endPoint: CGPoint(x: w, y: h)))
            // Water body
            var water = Path()
            water.move(to: CGPoint(x: w, y: h * 0.05))
            water.addCurve(to: CGPoint(x: w * 0.78, y: h * 0.95), control1: CGPoint(x: w * 0.7, y: h * 0.3),
                           control2: CGPoint(x: w * 0.95, y: h * 0.6))
            water.addLine(to: CGPoint(x: w, y: h)); water.closeSubpath()
            ctx.fill(water, with: .color(Color(hex: "#0C2333")))
            // Street grid (slightly rotated, jittered)
            var minor = Path(), major = Path()
            let step = max(w, h) / 22
            var i: CGFloat = -h
            while i < w + h {
                let j = CGFloat.random(in: -6...6, using: &rng)
                minor.move(to: CGPoint(x: i + j, y: 0)); minor.addLine(to: CGPoint(x: i + h * 0.35 + j, y: h))
                i += step * CGFloat.random(in: 0.7...1.3, using: &rng)
            }
            var k: CGFloat = 0
            while k < h {
                let j = CGFloat.random(in: -6...6, using: &rng)
                minor.move(to: CGPoint(x: 0, y: k + j)); minor.addLine(to: CGPoint(x: w, y: k - w * 0.12 + j))
                k += step * CGFloat.random(in: 0.7...1.3, using: &rng)
            }
            for _ in 0..<4 {
                let y0 = CGFloat.random(in: 0...h, using: &rng)
                major.move(to: CGPoint(x: 0, y: y0))
                major.addCurve(to: CGPoint(x: w, y: CGFloat.random(in: 0...h, using: &rng)),
                               control1: CGPoint(x: w * 0.3, y: CGFloat.random(in: 0...h, using: &rng)),
                               control2: CGPoint(x: w * 0.7, y: CGFloat.random(in: 0...h, using: &rng)))
            }
            ctx.stroke(minor, with: .color(Color(hex: "#1B3444").opacity(0.7)), lineWidth: 0.7)
            ctx.stroke(major, with: .color(Color(hex: "#2A5368").opacity(0.8)), lineWidth: 1.6)

            // Route
            var route = Path()
            let a = CGPoint(x: w * 0.52, y: h * 0.92), b = CGPoint(x: w * 0.45, y: h * 0.1)
            route.move(to: a)
            route.addCurve(to: CGPoint(x: w * 0.5, y: h * 0.5), control1: CGPoint(x: w * 0.25, y: h * 0.8),
                           control2: CGPoint(x: w * 0.75, y: h * 0.62))
            route.addCurve(to: b, control1: CGPoint(x: w * 0.25, y: h * 0.38), control2: CGPoint(x: w * 0.6, y: h * 0.2))
            var glow = ctx
            glow.addFilter(.blur(radius: 7))
            glow.stroke(route, with: .color(routeColor.opacity(0.9)), lineWidth: 9)
            ctx.stroke(route, with: .color(routeColor), style: StrokeStyle(lineWidth: 3.2, lineCap: .round))
            ctx.stroke(route, with: .color(.white.opacity(0.75)), style: StrokeStyle(lineWidth: 1, lineCap: .round))

            if showPins {
                for (pnt, c) in [(a, DS.green), (b, routeColor)] {
                    var g = ctx
                    g.addFilter(.blur(radius: 5))
                    g.fill(Path(ellipseIn: CGRect(x: pnt.x - 10, y: pnt.y - 10, width: 20, height: 20)), with: .color(c))
                    ctx.fill(Path(ellipseIn: CGRect(x: pnt.x - 6, y: pnt.y - 6, width: 12, height: 12)), with: .color(c))
                    ctx.fill(Path(ellipseIn: CGRect(x: pnt.x - 2.5, y: pnt.y - 2.5, width: 5, height: 5)), with: .color(.white))
                }
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Illustrations

struct ShieldShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addCurve(to: CGPoint(x: r.maxX, y: r.minY + r.height * 0.18),
                   control1: CGPoint(x: r.midX + r.width * 0.22, y: r.minY + r.height * 0.12),
                   control2: CGPoint(x: r.maxX - r.width * 0.1, y: r.minY + r.height * 0.14))
        p.addCurve(to: CGPoint(x: r.midX, y: r.maxY),
                   control1: CGPoint(x: r.maxX, y: r.minY + r.height * 0.62),
                   control2: CGPoint(x: r.midX + r.width * 0.25, y: r.maxY - r.height * 0.1))
        p.addCurve(to: CGPoint(x: r.minX, y: r.minY + r.height * 0.18),
                   control1: CGPoint(x: r.midX - r.width * 0.25, y: r.maxY - r.height * 0.1),
                   control2: CGPoint(x: r.minX, y: r.minY + r.height * 0.62))
        p.addCurve(to: CGPoint(x: r.midX, y: r.minY),
                   control1: CGPoint(x: r.minX + r.width * 0.1, y: r.minY + r.height * 0.14),
                   control2: CGPoint(x: r.midX - r.width * 0.22, y: r.minY + r.height * 0.12))
        return p
    }
}

/// Glowing shield with a check — "Never lose a deduction".
struct GlowShieldArt: View {
    var size: CGFloat = 110
    var color: Color = DS.cyan
    var symbol = "checkmark"
    var body: some View {
        ZStack {
            ShieldShape().fill(color.opacity(0.10))
            ShieldShape().stroke(color, lineWidth: 3).blur(radius: 6)
            ShieldShape().stroke(color, lineWidth: 2.5)
            ShieldShape().stroke(color.opacity(0.35), lineWidth: 1).padding(size * 0.08)
            Image(systemName: symbol)
                .font(.system(size: size * 0.34, weight: .bold))
                .foregroundStyle(color)
                .shadow(color: color, radius: 8)
        }
        .frame(width: size * 0.84, height: size)
        .accessibilityHidden(true)
    }
}

/// Phone with a lock inside glowing orbit rings — "Your data never leaves".
struct PhoneVaultArt: View {
    var size: CGFloat = 200
    var body: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { i in
                Ellipse()
                    .stroke(DS.cyan.opacity(0.55 - Double(i) * 0.12), lineWidth: 1.2)
                    .frame(width: size * (0.7 + CGFloat(i) * 0.28), height: size * (0.22 + CGFloat(i) * 0.09))
                    .shadow(color: DS.cyan, radius: 4)
                    .offset(y: size * 0.18)
            }
            RoundedRectangle(cornerRadius: size * 0.08, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: "#12202C"), Color(hex: "#060B10")], startPoint: .top, endPoint: .bottom))
                .overlay(RoundedRectangle(cornerRadius: size * 0.08, style: .continuous).stroke(DS.cyan.opacity(0.6), lineWidth: 1.5))
                .frame(width: size * 0.36, height: size * 0.64)
                .shadow(color: DS.cyan.opacity(0.5), radius: 16)
            Image(systemName: "lock.fill")
                .font(.system(size: size * 0.14, weight: .bold))
                .foregroundStyle(DS.cyan)
                .shadow(color: DS.cyan, radius: 10)
        }
        .frame(width: size * 1.6, height: size * 0.8)
        .accessibilityHidden(true)
    }
}

/// Concentric signal arcs — "Detects your drive" over the city.
struct SignalArcsArt: View {
    var size: CGFloat = 240
    @State private var pulse = false
    var body: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { i in
                let d = size * (0.35 + CGFloat(i) * 0.22)
                Circle()
                    .trim(from: 0.58, to: 0.92)
                    .stroke(DS.cyan.opacity(0.85 - Double(i) * 0.18), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: d, height: d)
                    .shadow(color: DS.cyan, radius: 6)
                    .opacity(pulse ? 1 : 0.55)
                    .animation(.easeInOut(duration: 1.2).repeatForever().delay(Double(i) * 0.15), value: pulse)
            }
        }
        .frame(width: size, height: size * 0.6, alignment: .bottom)
        .onAppear { pulse = true }
        .accessibilityHidden(true)
    }
}

/// Speedometer arc with a needle — paywall hero.
struct GaugeArt: View {
    var size: CGFloat = 130
    var value: Double = 0.8
    var body: some View {
        ZStack {
            Circle().trim(from: 0.12, to: 0.62).rotation(.degrees(90 + 54 - 43))
                .stroke(Color.white.opacity(0.08), style: StrokeStyle(lineWidth: 10, lineCap: .round))
            Circle().trim(from: 0.12, to: 0.12 + 0.5 * value).rotation(.degrees(90 + 54 - 43))
                .stroke(DS.brandGradient, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .shadow(color: DS.cyan, radius: 8)
            ForEach(0..<11, id: \.self) { i in
                Capsule().fill(Color.white.opacity(0.35))
                    .frame(width: 1.5, height: 7)
                    .offset(y: -size * 0.36)
                    .rotationEffect(.degrees(-90 + Double(i) * 18))
            }
            Text("PRO")
                .font(DS.display(size * 0.13))
                .foregroundStyle(.white)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(DS.cyan, lineWidth: 1.5))
                .shadow(color: DS.cyan, radius: 6)
                .offset(y: size * 0.18)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - Card art (replaces the old raster card banners)

/// Trailing-edge vector artwork behind Vault / Rules cards, with a left fade for legible text.
/// `imageName` keeps the old asset keys so call sites stay unchanged.
struct CardArtBackground: View {
    let imageName: String
    var aspectRatio: Double = 1024.0 / 377.0
    var trailingOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .trailing) {
                Color(hex: "#060B14")
                if let photo = photoName, UIImage(named: photo) != nil {
                    PhotoFill(name: photo, vignette: false)
                } else {
                    art(geo.size)
                        .frame(width: geo.size.width * 0.6, height: geo.size.height)
                        .clipped()
                        .offset(x: trailingOffset)
                }
                LinearGradient(stops: [
                    .init(color: Color(hex: "#060B14"), location: 0.0),
                    .init(color: Color(hex: "#060B14").opacity(0.96), location: 0.45),
                    .init(color: Color(hex: "#060B14").opacity(0.6), location: 0.6),
                    .init(color: .clear, location: 0.8)
                ], startPoint: .leading, endPoint: .trailing)
            }
        }
    }

    private var photoName: String? {
        switch imageName {
        case "vault_hero_bg": return "card_vault"
        case "rules_workshift_bg": return "card_workshift"
        case "rules_geofence_bg": return "map_geofence"
        default: return nil
        }
    }

    private static let photos = ["vault_hero_bg": "card_vault", "rules_workshift_bg": "card_workshift",
                                 "rules_geofence_bg": "map_geofence"]
    private var hasPhoto: Bool { Self.photos[imageName].flatMap { UIImage(named: $0) } != nil }

    @ViewBuilder
    private func art(_ size: CGSize) -> some View {
        switch imageName {
        case "vault_hero_bg":       ScenicBackdrop(style: .mountainLake, horizon: 0.55, vignette: false, seed: 31, photo: "card_vault")
        case "rules_workshift_bg":  ScenicBackdrop(style: .alpineDawn, horizon: 0.6, vignette: false, seed: 37, photo: "card_workshift")
        case "rules_geofence_bg":   MapRouteArt(seed: 43, photo: "map_geofence")
        case "vault_export_pdf_bg": glowSymbol("doc.richtext", size)
        case "vault_export_csv_bg": glowSymbol("tablecells", size)
        case "vault_privacy_shield_bg": GlowShieldArt(size: size.height * 0.75, symbol: "lock.fill")
        case "rules_bluetooth_bg":  glowSymbol("antenna.radiowaves.left.and.right", size)
        case "rules_coremotion_bg": glowSymbol("gyroscope", size)
        default:                    ScenicBackdrop(style: .mountainLake, showRoad: false, vignette: false)
        }
    }

    private func glowSymbol(_ name: String, _ size: CGSize) -> some View {
        ZStack {
            RadialGradient(colors: [DS.cyan.opacity(0.22), .clear], center: .center, startRadius: 0, endRadius: size.height * 0.7)
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .stroke(DS.cyan.opacity(0.28 - Double(i) * 0.08), lineWidth: 1)
                    .frame(width: size.height * (0.55 + CGFloat(i) * 0.3))
            }
            Image(systemName: name)
                .font(.system(size: size.height * 0.3, weight: .light))
                .foregroundStyle(DS.cyan)
                .shadow(color: DS.cyan, radius: 10)
        }
    }
}

#if DEBUG
/// Debug-only gallery: launch with `-artPage N` to inspect the vector art.
struct ArtGalleryView: View {
    let page: Int
    var body: some View {
        ZStack {
            DS.bg.ignoresSafeArea()
            switch page {
            case 0: ScenicBackdrop(style: .mountainLake).ignoresSafeArea()
            case 1: ScenicBackdrop(style: .alpineDawn).ignoresSafeArea()
            case 2: ScenicBackdrop(style: .cityNight).ignoresSafeArea()
            case 3: ScenicBackdrop(style: .coastal).ignoresSafeArea()
            case 4: MapRouteArt().ignoresSafeArea()
            default:
                VStack(spacing: 30) {
                    HStack(spacing: 30) { GlowShieldArt(); GaugeArt() }
                    PhoneVaultArt()
                    SignalArcsArt()
                }
            }
        }
    }
}
#endif
