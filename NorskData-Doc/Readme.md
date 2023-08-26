# Norsk Data Documentation

This folder contains PDF's containing ND documentation.
They have been scanned and OCR'ed from original paper documentation.



## ND-120 Documentsion

Introduction to the hardware changes in the ND-120

* [DELILAH Hardware Introduction](DELILAH%20Hardware%20Introduction-ocr.pdf)

See also the video training delivered by Lasse Bockelie and Chris Cherrington, the original hw designers.

* [ND-120 - DELILAH - Hardware Introduction - Part 1 of 2](https://www.youtube.com/watch?v=BzN33BQFg8g)
* [ND-120 - DELILAH - Hardware Introduction - Part 2 of 2](https://www.youtube.com/watch?v=g3bIK9gkGyM)


## ND-110 Documentation

These documents are for the ND-110 CPU and Architecture.
The functional description and instruction set is identical in the ND-120.

* [ND-06.026.1 EN ND-110 Functional Description](ND-06026-1-EN%20ND-110%20Functional%20Description-ocr.pdf)
* [ND-06.029-1 EN ND-110 Instruction Set](ND-06029-1-EN%20ND-110%20Instruction%20Set-ocr.pdf)


## ND-110 and ND-120 Microprogramming

This document contain details on how to program the microcode in the ND-110 and ND-110 CPU.

* [ND-06.031.1 EN ND-110 and ND-120 Microprogrammer's Guide](ND-06.031.1%20EN%20ND-110%20and%20ND-120%20Microprogrammer's%20Guide-Gandalf-OCR.pdf)



## Difference ND-110 and ND-120
The differences between ND-110 and ND-120 is mainly speed (about 1.5x) as the "Cpu Gate Array/DELILAH" chip is able to run at higher speed (with shorter cycle times) then the original discrete TTL chips in the ND-110.

The ND-120 can also address more RAM, up from 2MB on the ND-110 to 6MB on the ND-120.

The ND-120 finally moved to RS-232 for the console, while all earlier models from Nord-1 used current-loop.
This detail is hidden from the operating system by the microcode that addresses the on-board UART.