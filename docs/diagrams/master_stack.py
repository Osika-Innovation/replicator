#!/usr/bin/env python3
"""Generate the master subsystem block diagram and the subsystem zone map.

    python3 docs/diagrams/master_stack.py            # rewrite both guides in place
    python3 docs/diagrams/master_stack.py --print    # print the SVG only

The SVG is spliced between marker comments in docs/content/architecture.md
(MASTER_STACK) and docs/content/subsystems.md (ZONE_MAP). Numbers stay as
{{c:...}} tokens, so tools/build_docs.py fills them from docs/canon.json.
Edit the block lists below, not the SVG in the guides.
"""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]

FLOW = {  # key: (colour, name)
    'matter': ('#9a542e', 'Matter and return'),
    'act': ('#166b60', 'Actuation'),
    'sense': ('#2b5fa8', 'Sensing and telemetry'),
    'power': ('#a8323a', 'Power and heat'),
}
INK, BODY, OPEN_INK = '#173630', '#3d4d47', '#9a542e'


def esc(s):
    return s.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')


def block(x, y, w, h, href, title, lines, ev, flows, bar=False):
    on = ' '.join('on-' + f for f in flows)
    out = [f'<a href="{href}" class="bk {on}" aria-label="{esc(title)}">',
           f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="7" fill="#fffefa" stroke="{INK}" stroke-width="1.2"/>']
    if bar:
        out.append(f'<text x="{x + 10}" y="{y + h / 2 + 4:g}" font-size="11.5" fill="{INK}"><tspan font-weight="600">{esc(title)}</tspan> · {esc(lines[0])}</text>')
    else:
        out.append(f'<text x="{x + 10}" y="{y + 18}" font-size="12.5" font-weight="600" fill="{INK}">{esc(title)}</text>')
        for i, line in enumerate(lines):
            out.append(f'<text x="{x + 10}" y="{y + 33 + 13 * i}" font-size="10" fill="{BODY}">{esc(line)}</text>')
    fill = OPEN_INK if 'OPEN' in ev else FLOW['act'][0]
    ey = y + h - 6 if not bar else y + h / 2 + 3.5
    ex = x + w - 9 - (len(flows) * 10 + 4 if bar else 0)
    out.append(f'<text x="{ex:g}" y="{ey:g}" font-size="8.3" letter-spacing=".4" text-anchor="end" fill="{fill}">{esc(ev)}</text>')
    for i, f in enumerate(flows):  # flow chips: bottom left, or right end of a bar
        cx, cy = (x + w - 11 - 10 * i, y + h / 2) if bar else (x + 13 + 10 * i, y + h - 9)
        out.append(f'<circle class="fl fl-{f}" cx="{cx:g}" cy="{cy:g}" r="3.6" fill="{FLOW[f][0]}"/>')
    out.append('</a>')
    return '\n'.join(out)


def frame(x, y, w, h, fill, title, detail, dash=False):
    d = ' stroke-dasharray="6 4"' if dash else ''
    return (f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="12" fill="{fill}" stroke="{INK}" stroke-width="1.5"{d}/>\n'
            f'<text x="{x + 15}" y="{y + 21}" font-size="12.5" font-weight="700" letter-spacing=".6" fill="{INK}">{esc(title)}</text>\n'
            f'<text x="{x + 15}" y="{y + 36}" font-size="10" fill="{BODY}">{esc(detail)}</text>')


def bus(key, x, y0, y1, taps):
    c = FLOW[key][0]
    out = [f'<g class="fl fl-{key}" stroke="{c}" fill="none" stroke-width="2.6">', f'<path d="M{x} {y0} V{y1}"/>']
    left = x < 120
    edge = 120 if left else 800
    stop = edge + (-7 if left else 7)
    for ty, kind in taps:
        if kind == 'src':  # the bus is fed from this zone
            out.append(f'<path d="M{edge} {ty} H{x}"/><circle cx="{edge}" cy="{ty}" r="4" fill="{c}" stroke="none"/>')
        elif kind == 'both':
            out.append(f'<path d="M{x} {ty} H{stop}" marker-end="url(#ms-{key})"/><path d="M{edge} {ty + 12} H{x + (7 if left else -7)}" stroke-dasharray="5 3" marker-end="url(#ms-{key})"/>')
        else:
            out.append(f'<path d="M{x} {ty} H{stop}" marker-end="url(#ms-{key})"/>')
    out.append('</g>')
    return '\n'.join(out)


def bus_label(key, xs, lines):
    c = FLOW[key][0]
    out = []
    for lx, line in zip(xs, lines):
        out.append(f'<text class="fl fl-{key}" transform="rotate(-90 {lx} 480)" x="{lx}" y="480" text-anchor="middle" font-size="10" font-weight="600" fill="{c}" stroke="#fffefa" stroke-width="3.5" paint-order="stroke">{esc(line)}</text>')
    return '\n'.join(out)


def master():
    p = ['<svg viewBox="0 0 912 1140" role="group" aria-labelledby="ms-title ms-desc" xmlns="http://www.w3.org/2000/svg" font-family="system-ui,-apple-system,Segoe UI,sans-serif">',
         '<title id="ms-title">Master subsystem block diagram of the unified cylindrical two-zone stack</title>',
         '<desc id="ms-desc">An upper build cylinder sits on a mid-plane reflector and transfer gate, which sits on a lower plinth holding storage, release, power and compute. A workstation is tethered below. Four colour-coded buses run alongside: matter and return, actuation, sensing and telemetry, and power and heat. Every block links to its subsystem guide.</desc>',
         '<defs>']
    for k, (c, _) in FLOW.items():
        p.append(f'<marker id="ms-{k}" markerWidth="8" markerHeight="8" refX="6.5" refY="4" orient="auto" markerUnits="userSpaceOnUse"><path d="M0 .8 L7 4 L0 7.2z" fill="{c}"/></marker>')
    p.append('</defs>')
    p.append(f'<text x="120" y="30" font-size="14" font-weight="700" fill="{INK}">Unified cylindrical two-zone stack</text>')
    p.append(f'<text x="800" y="30" font-size="10.5" text-anchor="end" fill="{BODY}">Desktop Replicator · every block is a link · dots mark its flows</text>')

    # ---- buses first, so blocks and labels sit above the lines
    p.append(bus('matter', 40, 300, 866, [(866, 'src'), (545, 'both'), (300, 'both')]))
    p.append(bus('power', 100, 125, 884, [(884, 'src'), (690, 'in'), (125, 'in')]))
    p.append(bus('act', 820, 112, 778, [(778, 'src'), (676, 'src'), (536, 'in'), (250, 'in'), (112, 'in')]))
    p.append(bus('sense', 866, 138, 705, [(138, 'src'), (360, 'src'), (568, 'src'), (705, 'in')]))
    p.append(bus_label('matter', (16, 29), [
        'MATTER AND RETURN · neutral grains and droplets only · charge ≤ {{c:electrostatics_and_matter_loop.max_bead_charge_pc}} pC per bead',
        'air at {{c:electrostatics_and_matter_loop.chamber_ambient_rh_pct_range|range}} % RH · fed up from the storage bucket through the cassette gate · gate mechanism OPEN · return (dashed)']))
    p.append(bus_label('power', (76, 89), [
        'POWER AND HEAT · USB-C in · {{c:haptic_pzt.bridge_rail_v}} V bridge rail · 5 V driver logic · 3.3 V logic and lasers',
        '17.0 W in total (22.5 W with the gate-array card) · ceiling kept 1.9 K warmer than floor']))
    p.append(bus_label('act', (838, 851), [
        'ACTUATION · 12 channels ≤ {{c:haptic_pzt.max_drive_v_peak_single_tone}} V peak · tones {{c:desktop_geometry.comb_tones_hz|khz}} kHz · timing step {{c:clock_and_bus.pio_tick_ns}} ns',
        'pattern ring {{c:clock_and_bus.transmit_ring_us}} µs · frame 10 ms · {{c:mosquito_smi.total_ommatidia}} lasers ≤ 5 mW each · no EM drive fitted']))
    p.append(bus_label('sense', (884, 897), [
        'SENSING AND TELEMETRY · 16-bit echo read · one {{c:clock_and_bus.capture_burst_us}} µs capture per 10 ms frame',
        'lock-in 4 ms for 8 channels · {{c:mosquito_smi.total_ommatidia}} optical rays · board bus 75 Mbit/s · calibrated read 2.3 ms']))

    # ---- upper build cylinder
    p.append(frame(120, 44, 680, 414, '#e9f1e9', 'UPPER BUILD CYLINDER',
                   'stock glass tube {{c:desktop_geometry.glass_cylinder_id_od_mm|x}} mm · {{c:desktop_geometry.gap_mm}} mm between the plates · lifts {{c:desktop_geometry.lift_stroke_mm}} mm with the head'))
    p.append(block(135, 92, 318, 66, 'acoustics.html', 'Upper acoustic lamina (in the head)',
                   ['{{c:desktop_geometry.ports_per_plate}} × PZT-8 Ø{{c:desktop_geometry.pzt_diameter_mm}} × {{c:desktop_geometry.pzt_thickness_mm}} mm · {{c:haptic_pzt.hbridge_driver_mpn}} full bridges',
                    'echo read on the drive wires by {{c:haptic_pzt.adc_fallback_mpn}}, 16 bit'], 'DESIGN · SIMULATED', ['act', 'sense', 'power']))
    p.append(block(467, 92, 318, 66, 'acoustics.html#known-limits', 'Gap actuator and resonance lock',
                   ['holds gap ÷ sound speed: 0.41 mm per kelvin, ± 0.07 mm',
                    '± 1 mm travel: three steppers in the head (CAD) · lock host-tested'], 'SIMULATED NEED · NOT ON A BOARD', ['act', 'sense']))
    p.append(block(135, 168, 650, 30, 'acoustics.html', 'Upper wafer',
                   ['undrilled Ø{{c:desktop_geometry.wafer_diameter_mm}} × {{c:desktop_geometry.wafer_thickness_mm}} mm borosilicate: source, reflector and microphone in one part'], 'DESIGN', ['act', 'sense'], bar=True))
    p.append(block(135, 208, 190, 198, 'optics.html', 'Optical ring (LightRead)',
                   ['{{c:mosquito_smi.total_ommatidia}} self-mixing lasers, {{c:mosquito_smi.laser_wavelength_nm}} nm', 'each laser is its own detector',
                    'shadow image of the object', 'optical phase of the sound field', 'tracks air temperature and gap',
                    'no cameras, no beam splitters', '', 'amplifier bandwidth at the', 'top tone: OPEN'], 'SIMULATED · OPEN', ['sense', 'power']))
    p.append(f'<rect x="337" y="208" width="246" height="198" rx="9" fill="#d6e6da" stroke="{INK}" stroke-width="1" stroke-dasharray="3 3"/>')
    p.append(f'<text x="460" y="226" font-size="11" font-weight="700" letter-spacing=".5" text-anchor="middle" fill="{INK}">ONE SHARED WORK VOLUME</text>')
    p.append(block(349, 234, 222, 50, 'manufacturing.html', 'Arrange and hold',
                   ['one 160 kHz tone lifts; the comb shapes'], 'SIMULATED', ['act', 'matter']))
    p.append(block(349, 290, 222, 50, 'manufacturing.html#consolidation', 'Join and consolidate',
                   ['addressed heat step; no recipe yet'], 'OPEN', ['act', 'matter']))
    p.append(block(349, 346, 222, 50, 'matter-loop.html', 'Scan, verify and remove',
                   ['echo check (LISTEN), absorb (REMOVE)'], 'SIMULATED', ['sense', 'matter']))
    p.append(block(595, 208, 190, 198, 'electromagnetics.html', 'Electric and magnetic',
                   ['none fitted by default', '', 'option: 12-arm spiral on wafer', 'option: Ø{{c:dissolve_and_toroidal.compact_toroid_collar_id_mm_range|range}} mm pulsed',
                    'ring coil at one crucible', '', 'large coils across the', 'chamber: ruled out', 'static bleed coating: OPEN'], 'SIMULATED · OPEN', ['act', 'power']))
    p.append(block(135, 416, 650, 30, 'desktop-replicator.html#the-enclosure', 'Glass wall',
                   ['draught shield · raises sound pressure {{c:desktop_geometry.chamber_gain_closed_gap_median|range}} × (gap median) · not a laser enclosure'], 'SIMULATED', ['act'], bar=True))

    # ---- mid-plane
    p.append(frame(120, 470, 680, 122, '#f5eade', 'MID-PLANE REFLECTOR AND TRANSFER GATE',
                   'one plane, two duties: reflect sound up, pass material up · layout trade in simulation'))
    mids = [('acoustics.html', 'Lower wafer', ['same part as the upper', 'source and reflector'], 'DESIGN', ['act', 'sense']),
            ('acoustics.html#known-limits', 'Hard end annulus', ['end reflection ≥ 0.85', 'measured first, no bead'], 'SIMULATED', ['act']),
            ('matter-loop.html', 'Transfer gate', ['gate slot in the cassette', 'mechanism not designed'], 'DESIGN · OPEN', ['matter']),
            ('desktop-replicator.html#heat', 'Thermal barrier', ['floor never warmer', 'than the ceiling'], 'DERIVED', ['power'])]
    for i, (href, t, l, ev, fl) in enumerate(mids):
        p.append(block(135 + 165 * i, 518, 155, 64, href, t, l, ev, fl))

    # ---- lower plinth
    p.append(frame(120, 604, 680, 312, '#e8ecf3', 'LOWER PLINTH: STORAGE, RELEASE, POWER, COMPUTE',
                   'coaxial under the build cylinder (ruled 24 Nov 2026) · drawn in the CAD as Rev S, the default build'))
    rows = [
        [('compute-control.html#drive-stage', 'Lower acoustic lamina', ['6 drive channels + 1 reference', '3 enable groups: 1 listens, 2 drive'], 'DESIGN', ['act', 'sense', 'power']),
         ('compute-control.html#clock-and-timing', 'Clock and bus backplane', ['{{c:clock_and_bus.xin_hz|mhz}} MHz + frame sync, skew ≤ {{c:clock_and_bus.sync_skew_max_ns}} ns', 'board bus 75 Mbit/s with CRC-32'], 'DERIVED', ['act', 'sense', 'power']),
         ('compute-control.html#in-the-desktop-replicator', 'Chamber and plinth sensors', ['I²C: 2 air thermometers, humidity', 'head-down switch · LED ring, camera'], 'DESIGN · PARTS OPEN', ['sense'])],
        [('cadence-memory.html', 'Compute card: Prime network', ['sparse, under {{c:cadence_brain.cadence_sparse_max_kb}} kB of memory', 'settle 15.4 kB + calibration 43.3 kB'], 'SIMULATED', ['act', 'sense', 'power']),
         ('digital-twin.html', 'Calibration and metrology', ['in-chamber spheres, reciprocity', 'new LMQ8 image per calibration'], 'SIMULATED', ['sense']),
         ('compute-control.html#drive-stage', 'Safety interlocks', ['head up: bridges off, lasers off', 'humidity gate in firmware: OPEN'], 'DESIGN · OPEN', ['act', 'power'])],
        [('matter-loop.html', 'Storage bucket', ['fixed glass tube under the cassette', 'same stock tube as the build tube'], 'DESIGN · SIM OPEN', ['matter', 'sense']),
         ('matter-loop.html', 'Release and reclaim', ['crucibles: powder, liquid, seed', 'removing joined material: OPEN'], 'OPEN', ['matter', 'act']),
         ('desktop-replicator.html#heat', 'Power and heat reject', ['USB-C in → {{c:haptic_pzt.bridge_rail_v}} V, 5 V, 3.3 V', '17.0 W · air path outside chamber'], 'DERIVED', ['power'])],
    ]
    for r, row in enumerate(rows):
        for c, (href, t, l, ev, fl) in enumerate(row):
            p.append(block(135 + 221 * c, 652 + 88 * r, 208, 76, href, t, l, ev, fl))

    # ---- tether + workstation
    sc = FLOW['sense'][0]
    p.append(f'<g class="fl fl-sense fl-act" stroke="{sc}" stroke-width="2.6" fill="none"><path d="M452 920 V943" marker-end="url(#ms-sense)"/><path d="M468 946 V923" marker-end="url(#ms-sense)"/></g>')
    p.append(f'<text class="fl fl-sense fl-act" x="442" y="937" font-size="10" text-anchor="end" fill="{sc}" font-weight="600">USB-C tether · down: frames, goal packet (1,556 B), calibration (≤ 43.3 kB)</text>')
    p.append(f'<text class="fl fl-sense fl-act" x="478" y="937" font-size="10" fill="{sc}" font-weight="600">up: recorded echoes and optical readings</text>')
    p.append(frame(120, 950, 680, 112, '#fffefa', 'WORKSTATION (OFF THE MACHINE)', 'plans, trains and keeps the record · the machine is meant to keep running when unplugged', dash=True))
    ws = [('digital-twin.html', 'Digital twin and planner', ['CAD · field models · equation → frames'], 'SIMULATED', ['act', 'sense']),
          ('cadence-memory.html', 'Prime training', ['world model · verifier-gated updates'], 'SIMULATED', ['sense']),
          ('evidence.html', 'Evidence ledger', ['labels, gates and published basis'], 'DOCUMENTED', [])]
    for c, (href, t, l, ev, fl) in enumerate(ws):
        p.append(block(135 + 221 * c, 996, 208, 56, href, t, l, ev, fl))

    # ---- legend
    p.append(f'<text x="120" y="1088" font-size="10.5" font-weight="700" fill="{INK}">FLOWS</text>')
    for i, (k, (c, name)) in enumerate(FLOW.items()):
        x = 176 + 158 * i
        p.append(f'<g class="fl fl-{k}"><path d="M{x} 1084 H{x + 24}" stroke="{c}" stroke-width="3"/><text x="{x + 30}" y="1088" font-size="10.5" fill="{c}" font-weight="600">{esc(name)}</text></g>')
    p.append(f'<text x="120" y="1108" font-size="10.5" font-weight="700" fill="{INK}">LABELS</text>')
    p.append(f'<text x="176" y="1108" font-size="10.5" fill="{BODY}">DESIGN decision · DOCUMENTED external source · DERIVED calculation · SIMULATED project model</text>')
    p.append(f'<text x="176" y="1124" font-size="10.5" fill="{BODY}"><tspan fill="{OPEN_INK}" font-weight="600">OPEN</tspan> not settled · no block in this diagram is MEASURED</text>')
    p.append('</svg>')
    return '\n'.join(p)


def zone_map():
    """Small clickable index for the subsystem guide: zones -> datasheet anchors."""
    zones = [
        ('UPPER BUILD CYLINDER', '#e9f1e9', [('s01-chamber-and-stack-topology', 'S01 Chamber and stack'), ('s04-acoustic-array', 'S04 Acoustic array'),
                                              ('s05-gap-actuator-and-resonance-lock', 'S05 Gap lock'), ('s06-optical-tomography', 'S06 Optical ring'),
                                              ('s07-electromagnetics-and-consolidation', 'S07 EM and joining')]),
        ('MID-PLANE', '#f5eade', [('s03-mid-plane-interface', 'S03 Mid-plane interface')]),
        ('LOWER PLINTH', '#e8ecf3', [('s02-storage-and-release-plinth', 'S02 Storage and release'), ('s08-control-and-firmware', 'S08 Control and firmware'),
                                      ('s09-prime-world-model', 'S09 Prime model'), ('s10-metrology-and-calibration', 'S10 Metrology'),
                                      ('s11-thermal-and-safety', 'S11 Thermal and safety')]),
    ]
    p = ['<svg viewBox="0 0 860 236" role="group" aria-labelledby="zm-title zm-desc" xmlns="http://www.w3.org/2000/svg" font-family="system-ui,-apple-system,Segoe UI,sans-serif">',
         '<title id="zm-title">Subsystem index by zone</title>',
         '<desc id="zm-desc">The three zones of the stack with the eleven subsystem datasheets on this page. Each chip jumps to its datasheet.</desc>']
    y = 8
    for name, fill, chips in zones:
        p.append(f'<rect x="8" y="{y}" width="844" height="66" rx="10" fill="{fill}" stroke="{INK}" stroke-width="1.3"/>')
        p.append(f'<text x="22" y="{y + 20}" font-size="11.5" font-weight="700" letter-spacing=".6" fill="{INK}">{name}</text>')
        for i, (anchor, label) in enumerate(chips):
            x = 22 + 164 * i
            p.append(f'<a href="#{anchor}" class="bk" aria-label="{esc(label)}"><rect x="{x}" y="{y + 28}" width="156" height="28" rx="6" fill="#fffefa" stroke="{INK}" stroke-width="1.1"/>'
                     f'<text x="{x + 78}" y="{y + 46}" font-size="11.5" text-anchor="middle" fill="{INK}">{esc(label)}</text></a>')
        y += 76
    p.append('</svg>')
    return '\n'.join(p)


def splice(path, name, svg):
    text = path.read_text()
    pattern = re.compile(rf'(<!-- {name}:BEGIN -->\n).*?(<!-- {name}:END -->)', re.S)
    if not pattern.search(text):
        raise SystemExit(f'{path.name}: markers for {name} not found')
    path.write_text(pattern.sub(lambda m: m.group(1) + svg + '\n' + m.group(2), text))


if __name__ == '__main__':
    if '--print' in sys.argv:
        print(master())
    else:
        splice(ROOT / 'docs/content/architecture.md', 'MASTER_STACK', master())
        splice(ROOT / 'docs/content/subsystems.md', 'ZONE_MAP', zone_map())
        print('Spliced MASTER_STACK and ZONE_MAP.')
