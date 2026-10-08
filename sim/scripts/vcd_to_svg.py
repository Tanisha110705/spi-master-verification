#!/usr/bin/env python3
"""Render a time window of a VCD file as an annotated SVG timing diagram.

Used to produce assets/sim-waveform-mode*.svg from the VCD written by
sim/scripts/run_verilator.sh. No third-party packages are required.

Example:
  python3 sim/scripts/vcd_to_svg.py sim/build_verilator_mode0/dump.vcd \
      --start 120 --end 1000 --mode 0 -o assets/sim-waveform-mode0.svg
"""
import argparse
from html import escape

SIGNALS = [  # (hierarchical suffix, label, kind)
    ("UUT.i_TX_DV", "i_TX_DV", "bit"),
    ("UUT.o_TX_Ready", "o_TX_Ready", "bit"),
    ("UUT.o_SPI_CS_n", "o_SPI_CS_n", "bit"),
    ("UUT.o_SPI_Clk", "o_SPI_Clk", "bit"),
    ("UUT.o_SPI_MOSI", "o_SPI_MOSI", "bit"),
    ("UUT.i_SPI_MISO", "i_SPI_MISO", "bit"),
    ("UUT.o_RX_DV", "o_RX_DV", "bit"),
    ("UUT.o_RX_Byte", "o_RX_Byte", "bus"),
]


def parse_vcd(path):
    ids, changes, scope, t = {}, {}, [], 0
    with open(path) as fh:
        for line in fh:
            w = line.split()
            if not w:
                continue
            if w[0] == "$scope":
                scope.append(w[2])
            elif w[0] == "$upscope":
                scope.pop()
            elif w[0] == "$var":
                ids.setdefault(w[3], []).append(".".join(scope + [w[4]]))
            elif w[0].startswith("#"):
                t = int(w[0][1:])
            elif w[0][0] in "01xz" and len(w) == 1:
                changes.setdefault(w[0][1:], []).append((t, w[0][0]))
            elif w[0][0] == "b":
                changes.setdefault(w[1], []).append((t, w[0][1:]))
    return ids, changes


def lookup(ids, changes, suffix):
    for code, names in ids.items():
        if any(n.endswith(suffix) for n in names):
            return changes.get(code, [])
    raise SystemExit(f"signal {suffix} not found")


def value_at(trace, t):
    v = trace[0][1] if trace else "x"
    for tt, vv in trace:
        if tt > t:
            break
        v = vv
    return v


def segments(trace, t0, t1):
    segs, cur = [], value_at(trace, t0)
    start = t0
    for tt, vv in trace:
        if t0 < tt < t1 and vv != cur:
            segs.append((start, tt, cur))
            start, cur = tt, vv
    segs.append((start, t1, cur))
    return segs


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("vcd")
    ap.add_argument("--start", type=int, required=True)
    ap.add_argument("--end", type=int, required=True)
    ap.add_argument("--mode", type=int, required=True, choices=range(4))
    ap.add_argument("--title", default="")
    ap.add_argument("--note", default="", help="caption printed under the time axis")
    ap.add_argument("-o", "--out", required=True)
    a = ap.parse_args()

    ids, changes = parse_vcd(a.vcd)
    t0, t1 = a.start, a.end
    cpol, cpha = a.mode >> 1, a.mode & 1

    lw, rw, top, row, amp = 120, 860, 70, 42, 22
    width = lw + rw + 30
    height = top + row * len(SIGNALS) + (80 if a.note else 50)
    x = lambda t: lw + (t - t0) * rw / (t1 - t0)

    out = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
        f'viewBox="0 0 {width} {height}" font-family="Helvetica, Arial, sans-serif" font-size="12">',
        f'<rect width="{width}" height="{height}" fill="#ffffff"/>',
        f'<text x="16" y="24" font-size="15" font-weight="bold" fill="#1f2328">{escape(a.title)}</text>',
        f'<text x="16" y="44" fill="#57606a">SPI mode {a.mode} (CPOL={cpol}, CPHA={cpha}). '
        f'Dashed lines: o_SPI_Clk edges on which the DUT samples i_SPI_MISO '
        f'({"trailing" if cpha else "leading"} edge). Time axis in simulation time units.</text>',
    ]

    # DUT MISO sample edges = leading edge when CPHA=0, trailing edge when CPHA=1.
    clk = lookup(ids, changes, "UUT.o_SPI_Clk")
    idle = str(cpol)
    sample_edges = []
    for tt, vv in clk:
        if t0 < tt < t1:
            leading = vv != idle
            if leading != bool(cpha):
                sample_edges.append(tt)
    y_lo, y_hi = top - 8, top + row * len(SIGNALS) - 10
    for tt in sample_edges:
        out.append(f'<line x1="{x(tt):.1f}" y1="{y_lo}" x2="{x(tt):.1f}" y2="{y_hi}" '
                   f'stroke="#cf222e" stroke-width="1" stroke-dasharray="4 3" opacity="0.7"/>')

    for i, (suffix, label, kind) in enumerate(SIGNALS):
        base = top + row * i + amp + 4
        hi = base - amp
        out.append(f'<text x="{lw - 10}" y="{base - amp / 2 + 4}" text-anchor="end" '
                   f'font-family="Menlo, Consolas, monospace" fill="#1f2328">{label}</text>')
        out.append(f'<line x1="{lw}" y1="{base + 8}" x2="{lw + rw}" y2="{base + 8}" stroke="#eaeef2"/>')
        trace = lookup(ids, changes, suffix)
        if kind == "bit":
            pts, prev = [], None
            for s, e, v in segments(trace, t0, t1):
                y = hi if v == "1" else base
                if prev is not None:
                    pts.append(f"{x(s):.1f},{prev:.1f}")
                pts.append(f"{x(s):.1f},{y:.1f}")
                pts.append(f"{x(e):.1f},{y:.1f}")
                prev = y
            out.append(f'<polyline points="{" ".join(pts)}" fill="none" stroke="#0969da" stroke-width="1.6"/>')
        else:
            for s, e, v in segments(trace, t0, t1):
                xs, xe = x(s), x(e)
                out.append(f'<polygon points="{xs:.1f},{base - amp / 2:.1f} {xs + 4:.1f},{hi:.1f} '
                           f'{xe - 4:.1f},{hi:.1f} {xe:.1f},{base - amp / 2:.1f} {xe - 4:.1f},{base:.1f} '
                           f'{xs + 4:.1f},{base:.1f}" fill="#ddf4ff" stroke="#0969da" stroke-width="1.2"/>')
                txt = f"{int(v, 2):02X}" if set(v) <= {"0", "1"} else v
                if xe - xs > 24:
                    out.append(f'<text x="{(xs + xe) / 2:.1f}" y="{base - amp / 2 + 4:.1f}" text-anchor="middle" '
                               f'font-family="Menlo, Consolas, monospace" fill="#1f2328">{txt}</text>')

    ay = top + row * len(SIGNALS) + 6
    out.append(f'<line x1="{lw}" y1="{ay}" x2="{lw + rw}" y2="{ay}" stroke="#57606a"/>')
    step = max(1, int(round((t1 - t0) / 8, -2)))
    t = (t0 // step + 1) * step
    while t < t1:
        out.append(f'<line x1="{x(t):.1f}" y1="{ay}" x2="{x(t):.1f}" y2="{ay + 5}" stroke="#57606a"/>')
        out.append(f'<text x="{x(t):.1f}" y="{ay + 18}" text-anchor="middle" fill="#57606a">{t}</text>')
        t += step
    if a.note:
        out.append(f'<text x="16" y="{ay + 46}" fill="#cf222e">{escape(a.note)}</text>')
    out.append("</svg>")
    with open(a.out, "w") as fh:
        fh.write("\n".join(out) + "\n")


if __name__ == "__main__":
    main()
