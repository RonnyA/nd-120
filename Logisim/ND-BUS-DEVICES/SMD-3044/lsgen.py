# Helpers that write Logisim-Evolution 3.8.0 circuits from a net list.
#
# Every part is either a Logisim TTL chip or a subcircuit drawn as a DIP, and
# every connection is a tunnel sitting exactly on a DIP pin. Port positions
# come from Logisim's own code (AbstractTtlGate.updatePorts) and were checked
# headless before use:
#   pins 1..n/2   : (x + 10 + 20*(p-1), y + 30)      bottom edge, left to right
#   pins n/2+1..n : (x + w - 10 - 20*(p-1-n/2), y - 30)  top edge, right to left
# with w = 10*n and the part facing east.

from xml.sax.saxutils import quoteattr

LIB_WIRING, LIB_GATES, LIB_TTL, LIB_BASE, LIB_MEM = 0, 1, 2, 4, 5
LIB_DECL = [(0, "#Wiring"), (1, "#Gates"), (2, "#TTL"), (4, "#Base"), (5, "#Memory")]


def attr(name, val):
    return '<a name=%s val=%s/>' % (quoteattr(name), quoteattr(str(val)))


def dip_pin(npins, pin):
    # Pseudo-pins 101.. are extra ports in a row to the right of the body
    # (used for the Am2942's three-state data outputs, see parts.py).
    if pin > 100:
        return (npins * 10 + 20 * (pin - 100), 0)
    i = pin - 1
    half = npins // 2
    if i < half:
        return (i * 20 + 10, 30)
    return (npins * 10 - (i - half) * 20 - 10, -30)


# Gate pinouts (standard TTL; Logisim's TTL library uses the same pins).
GATES = {
    "7400": [((1, 2), 3), ((4, 5), 6), ((9, 10), 8), ((12, 13), 11)],
    "7408": [((1, 2), 3), ((4, 5), 6), ((9, 10), 8), ((12, 13), 11)],
    "7432": [((1, 2), 3), ((4, 5), 6), ((9, 10), 8), ((12, 13), 11)],
    "7486": [((1, 2), 3), ((4, 5), 6), ((9, 10), 8), ((12, 13), 11)],
    "7402": [((2, 3), 1), ((5, 6), 4), ((8, 9), 10), ((11, 12), 13)],
    "7404": [((1,), 2), ((3,), 4), ((5,), 6), ((9,), 8), ((11,), 10), ((13,), 12)],
    "7410": [((1, 2, 13), 12), ((3, 4, 5), 6), ((9, 10, 11), 8)],
    "7411": [((1, 2, 13), 12), ((3, 4, 5), 6), ((9, 10, 11), 8)],
    "7427": [((1, 2, 13), 12), ((3, 4, 5), 6), ((9, 10, 11), 8)],
    "7420": [((1, 2, 4, 5), 6), ((9, 10, 12, 13), 8)],
    "7430": [((1, 2, 3, 4, 5, 6, 11, 12), 8)],
}
NPINS = {"7400": 14, "7402": 14, "7404": 14, "7408": 14, "7410": 14, "7411": 14,
         "7420": 14, "7427": 14, "7430": 14, "7432": 14, "7451": 14, "7474": 14,
         "7486": 14, "74125": 14, "74138": 16, "74157": 16, "74161": 16,
         "74283": 16, "7485": 16, "74244": 20, "74245": 20, "74377": 20, "74175": 16}


class Circuit:
    def __init__(self, name):
        self.name = name
        self.lines = []
        self.chips = []          # (lib, part, label, {pin: net}, note)
        self.free = {}           # part -> list of (chip index, gate index) unused
        self.npins_override = {}

    # -- raw components ---------------------------------------------------
    def comp(self, lib, x, y, name, attrs=()):
        inner = "".join(attr(k, v) for k, v in attrs)
        lp = (' lib="%d"' % lib) if lib is not None else ""
        self.lines.append('    <comp%s loc="(%d,%d)" name=%s>%s</comp>'
                          % (lp, x, y, quoteattr(name), inner))

    def tunnel(self, x, y, net, facing, width=1):
        a = [("facing", facing), ("label", net)]
        if width != 1:
            a.append(("width", width))
        self.comp(LIB_WIRING, x, y, "Tunnel", a)

    def text(self, x, y, s, size=12, bold=False):
        self.comp(LIB_BASE, x, y, "Text",
                  [("font", "SansSerif %s %d" % ("bold" if bold else "plain", size)),
                   ("text", s)])

    def wire(self, x1, y1, x2, y2):
        self.lines.append('    <wire from="(%d,%d)" to="(%d,%d)"/>' % (x1, y1, x2, y2))

    # -- chips --------------------------------------------------------------
    def chip(self, part, nets, label, note=None, lib=LIB_TTL, npins=None):
        """A whole chip with an explicit pin -> net map."""
        self.chips.append((lib, part, label, dict(nets), note, npins or NPINS[part]))
        return len(self.chips) - 1

    def gate(self, part, ins, out):
        """Use one gate of a multi-gate chip; allocates chips as needed."""
        slots = self.free.setdefault(part, [])
        if not slots:
            idx = self.chip(part, {}, "%s#%d" % (part, sum(1 for c in self.chips if c[1] == part) + 1))
            slots.extend((idx, g) for g in range(len(GATES[part])))
        idx, g = slots.pop(0)
        pins_in, pin_out = GATES[part][g]
        assert len(ins) <= len(pins_in), (part, ins)
        nets = self.chips[idx][3]
        # unused inputs of a multi-input gate are tied to the gate's first input
        # so a 3-input gate can act as a 2-input one (AND/NAND/NOR/OR safe).
        for k, p in enumerate(pins_in):
            nets[p] = ins[k] if k < len(ins) else ins[0]
        nets[pin_out] = out
        return out

    def place_chips(self, x0, y0, cols, dx=260, dy=200):
        for k, (lib, part, label, nets, note, npins) in enumerate(self.chips):
            x = x0 + (k % cols) * max(dx, npins * 10 + 60)
            y = y0 + (k // cols) * dy
            self.comp(lib, x, y, part)
            for pin, net in nets.items():
                if net is None:
                    continue
                px, py = dip_pin(npins, pin)
                self.tunnel(x + px, y + py, net, "north" if py > 0 else "south")
            self.text(x + npins * 5, y - 50, label, 12, True)
            if note:
                for j, line in enumerate(note.split("\n")):
                    self.text(x + npins * 5, y + 50 + 14 * j, line, 9)

    # -- pins -------------------------------------------------------------
    def in_pin(self, x, y, net, width=1, label=None):
        a = [("facing", "east"), ("label", label or net)]
        if width != 1:
            a.append(("width", width))
        self.comp(LIB_WIRING, x, y, "Pin", a)
        self.tunnel(x, y, net, "west", width)

    def out_pin(self, x, y, net, width=1, label=None):
        a = [("facing", "west"), ("output", "true"), ("label", label or net)]
        if width != 1:
            a.append(("width", width))
        self.comp(LIB_WIRING, x, y, "Pin", a)
        self.tunnel(x, y, net, "east", width)

    def const(self, x, y, net, val):
        self.comp(LIB_WIRING, x, y, "Constant", [("value", "0x%x" % val)])
        self.tunnel(x, y, net, "west")

    def pull(self, x, y, net, val):
        self.comp(LIB_WIRING, x, y, "Pull Resistor", [("facing", "north"), ("pull", val)])
        self.tunnel(x, y, net, "east")

    def split(self, x, y, bus, bits, width, facing_out="east"):
        """Splitter whose combined end is at (x,y); fans out to tunnels `bits`.

        Logisim splitter (appear=left, facing east): combined end at (x,y),
        bit k at (x+20, y - 10*width + 10*k) - measured headless against a
        ROM word of 0xA5."""
        self.comp(LIB_WIRING, x, y, "Splitter",
                  [("fanout", width), ("incoming", width), ("appear", "left")])
        for k, b in enumerate(bits):
            self.tunnel(x + 20, y - 10 * width + 10 * k, b, "west")

    # -- output -----------------------------------------------------------
    def xml(self, appearance=None):
        out = ['  <circuit name=%s>' % quoteattr(self.name)]
        if appearance:
            out.append('    <a name="appearance" val="custom"/>')
        else:
            out.append('    <a name="appearance" val="logisim_evolution"/>')
        out.append('    <a name="circuit" val=%s/>' % quoteattr(self.name))
        if appearance:
            out.append("    <appear>")
            out.extend(appearance)
            out.append("    </appear>")
        out.extend(self.lines)
        out.append("  </circuit>")
        return out


def dip_appearance(npins, ports, title, port_locs):
    """Custom appearance putting each port on its DIP pin.

    ports: list of (dip pin, port name, is_output); several ports may share a
    pin (an input and a three-state output make one two-way pin).
    port_locs: port name -> (x, y) of the Pin component inside the circuit."""
    w = npins * 10
    parts = ['      <rect fill="#ffffff" height="50" stroke="#000000" stroke-width="2" '
             'width="%d" x="0" y="-25"/>' % w,
             '      <text dominant-baseline="central" font-family="SansSerif" font-size="12" '
             'font-weight="bold" text-anchor="middle" x="%d" y="0">%s</text>' % (w // 2, title)]
    labelled = set()
    for pin, pname, is_out in ports:
        dx, dy = dip_pin(npins, pin)
        s = 10 if is_out else 8
        px, py = port_locs[pname]
        parts.append('      <circ-port height="%d" pin="%d,%d" width="%d" x="%d" y="%d"/>'
                     % (s, px, py, s, dx - s // 2, dy - s // 2))
        if pin not in labelled:
            labelled.add(pin)
            ty = dy - 10 if dy > 0 else dy + 14
            nm = pname.split("_")[0]
            parts.append('      <text dominant-baseline="central" font-family="SansSerif" '
                         'font-size="7" text-anchor="middle" x="%d" y="%d">%d %s</text>'
                         % (dx, ty, pin, nm))
    parts.append('      <circ-anchor facing="east" height="6" width="6" x="-3" y="-3"/>')
    return parts


def project(circuits, main):
    head = ['<?xml version="1.0" encoding="UTF-8" standalone="no"?>',
            '<project source="3.8.0" version="1.0">',
            '  This file is intended to be loaded by Logisim-evolution v3.8.0'
            '(https://github.com/logisim-evolution/).']
    for n, d in LIB_DECL:
        head.append('  <lib desc="%s" name="%d"/>' % (d, n))
    head.append('  <main name=%s/>' % quoteattr(main))
    body = []
    for c in circuits:
        body.extend(c)
    return "\n".join(head + body + ["</project>"]) + "\n"
