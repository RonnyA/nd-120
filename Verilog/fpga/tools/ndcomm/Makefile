# ndcomm - ND-120 FPGA OPCOM console tool (BPUN loader / verifier / tracer)
CC      ?= cc
CFLAGS  ?= -O2 -Wall -Wextra

ndcomm: ndcomm.c
	$(CC) $(CFLAGS) -o $@ $<

clean:
	rm -f ndcomm

.PHONY: clean
