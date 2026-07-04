import sys
sys.path.insert(0, '/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/sim')
from fst import open_wave
VCD = '/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/sim/waveform.fst'
scope = []
found = []
count = 0
with open_wave(VCD) as f:
    for line in f:
        s = line.strip()
        if s.startswith(''):
            p = s.split()
            if len(p) >= 3: scope.append(p[2])
        elif s.startswith(''):
            if scope: scope.pop()
        elif s.startswith(''):
            p = s.split()
            if len(p) >= 5:
                full = '.'.join(scope + [p[4]])
                count += 1
                if count <= 30: found.append(full)
        elif s.startswith(''):
            break
print('Total signals: %d' % count)
for f in found: print(f)
