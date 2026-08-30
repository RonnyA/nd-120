# VT100 special keys - what the keyboard should send, and why

**Full path:** `Verilog/Terminals/docs/SPEC-vt100-keys.md`
Written 30-AUG-2026, after the VT100 terminal first ran on the Nexys.
Companion to [PLAN-vt100-terminal-core.md](PLAN-vt100-terminal-core.md).

The question: for arrows, Page Up/Down, Home, End, Insert, Delete and the
F-keys - alone and with Shift, Ctrl, Alt - which escape sequences should
`ps2_ascii_table.v` + `key_vt100.v` put on the wire?

## The two sources, and which one rules

1. **What SINTRAN actually decodes.** NDInsight's
   `Developer/Languages/Application/VTM-KEY-CODES.md` is a MEASURED table:
   every sequence was typed at a live D100 with the line set to terminal
   type 6, and the code `VTINBT` handed a PLANC program was read back
   (KEYPROB probe, 25-AUG-2026, marker-checked runs). No ND document
   describes this - that page is the only record.
2. **What a real terminal sends.** RetroTerm's `VT100KeyboardMapper`
   (`src/RetroTerm.Core/Terminal/Input/KeyboardMapper.cs:368`) and the DEC
   VT220 Programmer Reference (via that same NDInsight page).

**Source 1 rules.** A sequence VTM cannot decode does not merely do nothing -
it LEAKS: the bytes fall through as separate raw codes (`ESC[5~` on a
type-53 line came back as 27 91 53 126), and NDInsight's warning is blunt:
"never treat a stray 27 as a key". So the criterion for every key below is
*decoded by VTM type 6*, not *what xterm would send*.

## What VTM terminal type 6 is measured to decode

| Sequence | VTM code | DEC name | PC key it should come from |
|---|---|---|---|
| `ESC [ A` | 28  | cursor up | Up |
| `ESC [ B` | 11  | cursor down | Down |
| `ESC [ C` | 24  | cursor right | Right |
| `ESC [ D` | 8   | cursor left | Left |
| `ESC [ 1 ~` | 130 | FIND | **Home** (see below) |
| `ESC [ 2 ~` | 133 | INSERT HERE | Insert |
| `ESC [ 3 ~` | 129 | REMOVE | Delete |
| `ESC [ 4 ~` | 160 | SELECT | **End** (see below) |
| `ESC [ 5 ~` | 201 | PREV SCREEN | Page Up |
| `ESC [ 6 ~` | 197 | NEXT SCREEN | Page Down |

Plus the pass-throughs: printables as themselves, TAB 9, RETURN 13,
Ctrl-A..Z as 1..26 (VTM translates Backspace 8 -> 127; left arrow's 8 is
NOT translated, so the two stay distinguishable).

Notable: the editing six are **VT220 keys** - a real VT100 has no editing
keypad ("In VT100 or VT52 modes the editing keys do not generate codes") -
yet VTM's type-6 table decodes them anyway. Good for us: a PC keyboard has
exactly those six positions.

### Home and End - the one judgment call, and the current BUG

Today's build sends `ESC [ H` for Home (chosen when the marker scheme was
built, from the CUP-home analogy). **`ESC [ H` is xterm's Home, and it is
NOT in VTM's measured type-6 table** - so on a type-6 SINTRAN line it most
likely leaks as raw bytes. It must go.

A VT220 keyboard has no Home/End at all; xterm itself derives its Home/End
from DEC's FIND/SELECT positions. So: **PC Home sends `ESC [ 1 ~` (FIND),
PC End sends `ESC [ 4 ~` (SELECT)** - both measured-decoded. What a given
SINTRAN program DOES with codes 130/160 is that program's table; the point
is the codes arrive as one key each instead of as byte spray.

### F-keys

| PC key | Send | Why |
|---|---|---|
| F1..F4 | `ESC O P` / `Q` / `R` / `S` | DEC's keypad PF1..PF4. RetroTerm maps F1-F4 there in both its VT100 and VT220 mappers, so it is the convention every emulator follows. VTM measurement is incomplete (`ESC O P` gave 29 in one run, `ESC O Q` misbehaved in the same run) but the standard is what we send - see the decision below. |
| F5..F12 | `ESC [ 15~ 17~ 18~ 19~ 20~ 21~ 23~ 24~` | The DEC VT220 top-row codes (also what RetroTerm and every modern emulator send). |

(The gaps at 16 and 22 are DEC's, not typos.)

## Modifiers - the short, honest answer

**There is no Shift/Ctrl/Alt encoding for special keys in this era, and we
must not invent one.**

- The xterm forms (`ESC[1;5A` = Ctrl-Up, `ESC[1;2A` = Shift-Up, and
  `ESC[n;m~`) postdate SINTRAN's VTM by years. Sending them to a type-6
  line means undecoded byte spray - strictly worse than ignoring the
  modifier.
- A real VT220 sends the SAME sequence for a shifted editing/arrow key.
- **Alt is measured dead**: NDInsight sent `ESC`+letter (the Alt convention)
  and VTM handed back two separate codes, 27 then 97. Verdict recorded
  there: "Do not design around Alt."
- Terminal type 53 encodes shift as a *different sequence number*
  (F1=`ESC[50_`, shift-F1=`ESC[51_`) - a TDV property, nothing like it
  exists for type 6.

**Rules for the implementation:**

| Modifier + special key | Send |
|---|---|
| Shift + arrow/edit/F-key | the BASE sequence (what a VT220 does) |
| Ctrl + arrow/edit/F-key | the BASE sequence |
| Alt + anything | NOTHING extra - Alt is not tracked, not sent, reserved for possible LOCAL functions later (layout toggle etc.) |
| Ctrl + letter/digit/punct | already correct: C0 byte (existing decoder path) |
| Shift + printable | already correct: the shifted character |

## The marker scheme this needs (implementation sketch)

Today's markers are `0x80 | final` and cover five keys. The full set needs
three sequence FAMILIES, which fit the marker byte as two bits of family
plus five bits of payload - `key_vt100.v` grows from one expansion to
three:

| Marker | Expands to | Payload |
|---|---|---|
| `100f ffff` (0x80-0x9F) | `ESC [ <0x40+f>` | f: 1='A' 2='B' 3='C' 4='D' (arrows) |
| `101f ffff` (0xA0-0xBF) | `ESC O <0x40+f>` | f: 16='P' 17='Q' 18='R' 19='S' (PF1-4) |
| `110n nnnn` (0xC0-0xDF) | `ESC [ <n> ~` | n = 1..6 (edit keys), 15..24 (F5-F12); two-digit n emits two ASCII digits |

Bit 7 stays the marker flag (a 7-bit machine can never type it; a leaked
marker is visible, not silent). Longest expansion is 5 bytes (`ESC [ 2 4 ~`)
- the existing 8-deep FIFO still holds one whole sequence with room, but
  two F-keys inside one UART frame time would now overflow it: deepen to 16
  while in there.

PS/2 side (`ps2_ascii_table.v`): the six editing keys are E0-extended
(Insert E0 70, Delete E0 71, Home E0 6C, End E0 69, PgUp E0 7D, PgDn E0 7A)
- extend the existing `extended` table. **F1..F12 are NOT extended** - they
are plain set-2 codes (05 06 04 0C 03 0B 83 0A 01 09 78 07 for F1..F12,
note F7 = 0x83, the one two-byte-looking oddity) and sit in the MAIN table,
which today returns 0 for them; they need marker entries there, emitted for
both shifted and unshifted (rule above). Scancodes are transcription from
the published set-2 tables, same caveat as the rest of that file: unverified
against a physical keyboard until someone types on the real thing.

## Decision and implementation (Ronny, 30-AUG-2026)

**Follow the DEC VT100/VT220 standard wholesale - it is well documented; no
measuring.** Implemented the same day:

- `rtl/ps2_ascii_table.v` - the full marker table: arrows 0x81-0x84,
  editing six 0xC1-0xC6 (Home=FIND, End=SELECT; the `ESC [ H` Home is
  gone), F1-F4 0xB0-0xB3, F5-F12 0xCF/0xD1-0xD5/0xD7/0xD8. F-keys carry
  the SAME marker shifted and unshifted, per the standard.
- `rtl/ps2_decoder.v` - Ctrl never masks a marker (no Ctrl-F or Ctrl-arrow
  encoding exists on a VT100; the modifier is ignored). Alt is not tracked
  at all.
- `rtl/key_vt100.v` - three expansion families per the marker scheme above,
  incl. the one/two-digit `ESC [ n ~` form; FIFO deepened to 16.

The VTM measurements quoted earlier in this page remain what they are -
recorded fact about what SINTRAN's decoder was seen to do - and anyone who
later wants to close the F5-F12/PF question against a live host has
KEYPROB (VTM-KEY-CODES.md section 1) for it. The standard is what we send.
