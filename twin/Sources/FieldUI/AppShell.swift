import SwiftUI

/// The slicer shell (§16.1). A pure function of AppState — no @State, no
/// observation, no physics. That is law L1, and it is what makes every screen
/// screenshot-testable from a fixture.
public struct AppShell: View {
    public let s: AppState
    public let a: AppActions
    public init(_ s: AppState, actions: AppActions = AppActions()) {
        self.s = s; self.a = actions
    }

    public var body: some View {
        VStack(spacing: 0) {
            Toolbar(s: s, a: a)
            Divider().overlay(s.theme.stroke)
            HStack(spacing: 0) {
                ObjectRail(s: s, a: a).frame(width: 240)
                Divider().overlay(s.theme.stroke)
                ViewportPane(s: s, a: a).frame(maxWidth: .infinity)
                Divider().overlay(s.theme.stroke)
                Inspector(s: s).frame(width: 300)
            }
            Divider().overlay(s.theme.stroke)
            TransportBar(s: s, a: a)
        }
        .background(s.theme.background)
        .foregroundStyle(s.theme.text)
        .font(.system(size: 12))
        .environment(\.colorScheme, s.theme.isDark ? .dark : .light)
    }
}

struct Toolbar: View {
    let s: AppState
    var a = AppActions()
    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 2) {
                ForEach(AppMode.all, id: \.self) { m in
                    Clickable(enabled: a.setMode != nil) { a.setMode?(m) } label: {
                        Text(m.name)
                            .font(.system(size: 11.5,
                                          weight: m == s.mode ? .semibold : .regular))
                            .padding(.horizontal, 12).padding(.vertical, 5)
                            .background(m == s.mode ? s.theme.accent : Color.clear)
                            .foregroundStyle(m == s.mode ? s.theme.accentText
                                                         : s.theme.textDim)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                }
            }
            .padding(2)
            .background(s.theme.panelAlt)
            .clipShape(RoundedRectangle(cornerRadius: 7))

            Pill(text: s.machineName, theme: s.theme)
            if let setMaterial = a.setMaterial {
                Menu {
                    ForEach(s.materials, id: \.self) { m in
                        Button(m) { setMaterial(m) }
                    }
                } label: {
                    Pill(text: s.material, theme: s.theme)
                }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
            } else {
                Pill(text: s.material, theme: s.theme)
            }

            Spacer()

            Clickable(enabled: a.toggleMachineView != nil) {
                a.toggleMachineView?()
            } label: {
                Text(s.machineView ? "MACHINE VIEW" : "GOD VIEW")
                    .font(.system(size: 9.5, weight: .bold)).tracking(0.8)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(s.machineView ? s.theme.warn.opacity(0.22)
                                              : s.theme.panelAlt)
                    .foregroundStyle(s.machineView ? s.theme.warn : s.theme.textDim)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            Clickable(enabled: a.primaryAction != nil && s.busy == nil) {
                a.primaryAction?()
            } label: {
                Text(s.busy ?? (s.mode == .scan ? "Scan" : "Compile"))
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 18).padding(.vertical, 6)
                    .background(s.busy == nil ? s.theme.accent
                                              : s.theme.accent.opacity(0.45))
                    .foregroundStyle(s.theme.accentText)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
        .background(s.theme.panel)
    }
}

struct Pill: View {
    let text: String
    let theme: Theme
    var body: some View {
        HStack(spacing: 5) {
            Text(text).font(.system(size: 11.5))
            Text("⌄").font(.system(size: 9)).foregroundStyle(theme.textDim)
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(theme.panelAlt)
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }
}

struct ObjectRail: View {
    let s: AppState
    var a = AppActions()
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("OBJECTS", theme: s.theme)
            if s.objects.isEmpty {
                VStack(spacing: 6) {
                    Text("No objects").foregroundStyle(s.theme.textDim)
                    Text("Drop an STL to begin")
                        .font(.system(size: 10.5)).foregroundStyle(s.theme.textDim)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 28)
            } else {
                ForEach(s.objects) { o in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(o.name).font(.system(size: 12, weight: .medium))
                        Text("\(o.material) · \(o.detail)")
                            .font(.system(size: 10.5)).foregroundStyle(s.theme.textDim)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(o.selected ? s.theme.accent.opacity(0.16) : Color.clear)
                }
            }
            Divider().overlay(s.theme.stroke).padding(.vertical, 6)
            SectionHeader("MACHINE", theme: s.theme)
            KV("gates", "\(s.gateCount)", s.theme)
            KV("elements", "\(s.elementCount)", s.theme)
            KV("volume", s.buildVolumeText, s.theme)
            KV("band", s.wavelengthText, s.theme)
            Spacer()
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(s.theme.panel)
    }
}

struct ViewportPane: View {
    let s: AppState
    var a = AppActions()
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Color.clear drives the layout; the image is an overlay that is
            // clipped to it. Letting a .fill image size the ZStack lets the
            // viewport push the side rails off-canvas — which it did.
            Color(red: s.theme.viewportBackground.x,
                  green: s.theme.viewportBackground.y,
                  blue: s.theme.viewportBackground.z)
                .overlay {
                    if let img = s.viewport {
                        Image(decorative: img, scale: 1.0)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    }
                }
                .clipped()
            HStack(spacing: 6) {
                ForEach(["field", "traps", "matter", "solid", "boundary", "chords"], id: \.self) { c in
                    OverlayChip(name: c, on: s.overlays.contains(c), theme: s.theme,
                                action: a.toggleOverlay)
                }
            }
            .padding(10)
        }
    }
}

struct Inspector: View {
    let s: AppState
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(s.inspector) { sec in
                SectionHeader(sec.title.uppercased(), theme: s.theme)
                ForEach(Array(sec.rows.enumerated()), id: \.offset) { _, r in
                    KV(r.0, r.1, s.theme)
                }
                Spacer().frame(height: 8)
            }
            Spacer()
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(s.theme.panel)
    }
}

struct TransportBar: View {
    let s: AppState
    var a = AppActions()
    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 10) {
                Clickable(enabled: a.play != nil) { a.play?() } label: {
                    Text(s.isPlaying ? "❚❚" : "▶").font(.system(size: 11))
                }
                Clickable(enabled: a.step != nil) { a.step?(-1) } label: {
                    Text("◀").font(.system(size: 9))
                        .foregroundStyle(s.theme.textDim)
                }
                Clickable(enabled: a.step != nil) { a.step?(1) } label: {
                    Text("▶").font(.system(size: 9))
                        .foregroundStyle(s.theme.textDim)
                }
            }
            if let setFrame = a.setFrame {
                Slider(value: Binding(
                    get: { Double(s.frame) },
                    set: { setFrame(Int($0.rounded())) }),
                    in: 0...Double(max(1, s.frameCount)))
                    .controlSize(.small)
                    .tint(s.theme.accent)
            } else {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(s.theme.panelAlt).frame(height: 4)
                    let frac = s.frameCount > 0
                        ? Double(s.frame) / Double(s.frameCount) : 0
                    Capsule().fill(s.theme.accent)
                        .frame(width: max(0, geo.size.width * frac), height: 4)
                    Circle().fill(s.theme.accent).frame(width: 10, height: 10)
                        .offset(x: max(0, geo.size.width * frac - 5))
                }
                .frame(height: 12)
                .frame(maxHeight: .infinity)
            }
            .frame(height: 14)
            }

            Text(String(format: "t = %.1f ms", s.simTimeMs))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(s.theme.textDim)
            Text(String(format: "build %.0f%%", s.buildPercent))
                .font(.system(size: 11, design: .monospaced))
            if s.overspillPercent > 0 {
                Text(String(format: "overspill %.1f%%", s.overspillPercent))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(s.overspillPercent > 2 ? s.theme.bad : s.theme.warn)
            }
            Text(s.statusLine)
                .font(.system(size: 11)).foregroundStyle(s.theme.textDim)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(s.theme.panel)
    }
}

struct SectionHeader: View {
    let title: String
    let theme: Theme
    init(_ t: String, theme: Theme) { self.title = t; self.theme = theme }
    var body: some View {
        Text(title)
            .font(.system(size: 9.5, weight: .semibold)).tracking(0.9)
            .foregroundStyle(theme.textDim)
            .padding(.horizontal, 12).padding(.top, 12).padding(.bottom, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct KV: View {
    let k: String, v: String, theme: Theme
    init(_ k: String, _ v: String, _ t: Theme) { self.k = k; self.v = v; self.theme = t }
    var body: some View {
        HStack(alignment: .top) {
            Text(k).foregroundStyle(theme.textDim).font(.system(size: 11))
            Spacer(minLength: 8)
            Text(v).font(.system(size: 11, design: .monospaced))
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 12).padding(.vertical, 3)
    }
}


/// Renders its label unchanged; becomes a real button only when an action
/// exists. Keeps the screenshot path pixel-identical to the interactive one.
struct Clickable<Label: View>: View {
    let enabled: Bool
    let action: () -> Void
    @ViewBuilder let label: () -> Label
    var body: some View {
        if enabled {
            Button(action: action) { label() }
                .buttonStyle(.plain)
        } else {
            label()
        }
    }
}

struct OverlayChip: View {
    let name: String
    let on: Bool
    let theme: Theme
    let action: (@Sendable (String) -> Void)?
    var body: some View {
        Clickable(enabled: action != nil) { action?(name) } label: {
            Text(name)
                .font(.system(size: 10, weight: on ? .semibold : .regular))
                .padding(.horizontal, 9).padding(.vertical, 4)
                .background(on ? theme.accent.opacity(0.85) : Color.black.opacity(0.35))
                .foregroundStyle(on ? theme.accentText : Color.white.opacity(0.75))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }
}
