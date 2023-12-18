// RESET


void RESET(void)

{
  bool bVar1;
  char cVar2;
  
  DDRB = 0xff;
  DDRC = 0xff;
  DDRA = 0;
  Timer_Control_Reg = 0x78;
  PORTC = PORTC | 2;
  if ((PORTA & 8) == 0) {
    DAT_0014 = 0x60;
  }
  else {
    DAT_0014 = 0xe0;
  }
  FUN_023c(DAT_0014);
  DAT_0045 = 0;
  DAT_0018 = 0;
  DAT_0012 = 0;
  Timer_Data_Reg = 0;
  switchD_01a4::caseD_a4();
  FUN_05fc(0x38);
  FUN_05fc(0xc);
  FUN_05fc(6);
  FUN_0618();
  do {
    bVar1 = (bool)readIRQ();
  } while (!bVar1);
  do {
    cVar2 = readIRQ();
  } while (cVar2 != '\0');
  DAT_0012 = DAT_0012 & 0xc0;
  DAT_0013 = 5;
  DAT_0010 = DAT_0010 + -1;
  DAT_0015 = DAT_0012;
  if (((DAT_0010 == '\0') && (DAT_0011 = DAT_0011 + -1, DAT_0011 == '\0')) &&
     (DAT_0014 = DAT_0014 & 0xef, (DAT_0019 & 0x20) == 0)) {
    FUN_0618();
    DAT_0011 = '\x06';
  }
  WaitForData();
  return;
}



// Wait for Data


void WaitForData(void)

{
  char cVar1;
  char cVar2;
  char in_X;
  byte bVar3;
  bool bVar4;
  
  PORTB = DAT_0014;
  Timer_Data_Reg = 0;
  do {
    bVar4 = (bool)readIRQ();
    if (bVar4) {
      DAT_001a = '\0';
      PORTC = PORTC & 0xfe | 3;
      DAT_001e = DAT_004c;
      cVar2 = '\x05';
      goto LAB_0282;
    }
  } while ((PORTA & 0x3f) == 0);
  goto LAB_0292;
LAB_0282:
  cVar1 = readIRQ();
  if (cVar1 == '\0') {
    bVar3 = 8;
    do {
      do {
        PORTC = PORTC & 0xfd;
        PORTC = PORTC | 2;
        DAT_0020 = PORTA;
        DAT_0021 = DAT_0021 >> 1;
        DAT_0022 = DAT_0022 >> 1;
        DAT_0023 = DAT_0023 >> 1;
        if ((PORTA & 1) == 0) {
          DAT_0021 = DAT_0021 | 0x80;
        }
        if ((PORTA & 2) == 0) {
          DAT_0022 = DAT_0022 | 0x80;
        }
        if ((PORTA & 4) == 0) {
          DAT_0023 = DAT_0023 | 0x80;
        }
        DAT_001a = DAT_001a + '\x01';
      } while (DAT_001a != '\b');
      DAT_001a = '\0';
      bVar3 = bVar3 - 1;
      *(byte *)(bVar3 + 0x2d) = DAT_0021;
      *(byte *)(bVar3 + 0x35) = DAT_0022;
      *(byte *)(bVar3 + 0x3d) = DAT_0023;
    } while (bVar3 != 0);
    if (DAT_0019 != DAT_0018) {
      DAT_0018 = DAT_0019;
      FUN_0618();
      DAT_0047 = '\0';
    }
    DAT_0019 = 0;
    DAT_001b = DAT_002d;
    DAT_001c = DAT_002e;
    cVar2 = FUN_0641();
    DAT_001d = cVar2;
    if (cVar2 == '\0') {
      FUN_041d();
      return;
    }
    bVar3 = 0;
    DAT_001f = 1;
    while( true ) {
      *(char *)((bVar3 >> 1) + 0x25) = cVar2;
      DAT_001b = *(undefined *)((byte)(DAT_001f + 1) + 0x2d);
      bVar3 = DAT_001f + 2;
      if (bVar3 == 9) break;
      DAT_001c = *(undefined *)(bVar3 + 0x2d);
      cVar2 = FUN_0641();
    }
    if ((DAT_0018 & 0x20) == 0) {
      bVar3 = 3;
      do {
        *(char *)(bVar3 + 0x29) = *(char *)(bVar3 + 0x25);
        if (*(char *)(bVar3 + 0x25) != ' ') {
          DAT_0045 = 0;
          FUN_0690(0x40);
          goto LAB_03ab;
        }
        bVar3 = bVar3 - 1;
      } while (-1 < (char)bVar3);
      DAT_0047 = '\0';
      DAT_0045 = 0x60;
      DAT_0019 = DAT_0019 | 0x20;
    }
    else {
      bVar3 = 3;
      DAT_0019 = DAT_0019 | 0x20;
      while (*(char *)(bVar3 + 0x25) == *(char *)(bVar3 + 0x29)) {
        bVar3 = bVar3 - 1;
        if ((char)bVar3 < '\0') {
          if ((DAT_003a & 0x80) == 0) goto LAB_03ab;
          goto LAB_0346;
        }
      }
      DAT_001f = DAT_0025;
      bVar3 = 1;
      do {
        bVar4 = DAT_001f == *(byte *)(bVar3 + 0x29);
        DAT_001f = bVar3;
        if (bVar4) break;
        DAT_001f = bVar3 + 1;
        bVar3 = DAT_001f;
      } while (DAT_001f != 4);
      bVar3 = 4 - DAT_001f;
      do {
        if (DAT_0047 == '(') {
          DAT_0047 = '\0';
        }
        FUN_05fc(0x18);
        DAT_0047 = DAT_0047 + '\x01';
        FUN_0690(0x27);
        FUN_05d2(*(undefined *)(bVar3 + 0x25));
        bVar3 = bVar3 + 1;
      } while (bVar3 != 4);
      bVar3 = 0;
      do {
        *(undefined *)(bVar3 + 0x29) = *(undefined *)(bVar3 + 0x25);
        bVar3 = bVar3 + 1;
      } while (bVar3 != 4);
    }
    if ((DAT_003a & 0x80) != 0) {
LAB_0346:
      FUN_0690(0x40);
      FUN_060c();
      DAT_001f = 0;
      FUN_0623(DAT_0035);
      FUN_05d2();
      FUN_0623(*(undefined *)(DAT_001f + 0x35));
      FUN_05d2();
      if ((DAT_0038 & 0x80) != 0) {
        DAT_0019 = DAT_0019 | 0x10;
        FUN_060c();
      }
      FUN_0623(*(undefined *)(DAT_001f + 0x35));
      FUN_05d2();
      FUN_0623(*(undefined *)(DAT_001f + 0x35));
      FUN_05d2();
      if ((DAT_0038 & 0x80) == 0) {
        FUN_060c();
        bVar3 = DAT_001f + 2;
      }
      else {
        FUN_05d2(0x3a);
        FUN_0623(*(undefined *)(DAT_001f + 0x35));
        FUN_05d2();
        FUN_0623(*(undefined *)(DAT_001f + 0x35));
        FUN_05d2();
        FUN_05d2(0x3a);
        bVar3 = DAT_001f;
      }
      FUN_0623(*(undefined *)(bVar3 + 0x35));
      FUN_05d2();
      FUN_0623(*(undefined *)(DAT_001f + 0x35));
      FUN_05d2();
      FUN_0690(0x57);
      FUN_05d2(0x20);
      bVar3 = 0;
      do {
        DAT_001b = *(undefined *)(bVar3 + 0x3d);
        FUN_057c();
        bVar3 = bVar3 + 1;
      } while (bVar3 < 8);
      ProcessData();
      return;
    }
LAB_03ab:
    FUN_0690(DAT_0045);
    bVar3 = DAT_0019;
    DAT_0019 = DAT_0019 | 2;
    if ((bVar3 & 0x20) == 0) {
      if (DAT_0025 == 0x20) {
        FUN_060c();
      }
      else {
        FUN_060c();
      }
    }
    FUN_03cf(0x35);
    FUN_03f4();
    return;
  }
  in_X = in_X + -1;
  if (((in_X != '\0') || (cVar2 = cVar2 + -1, cVar2 != '\0')) ||
     (DAT_001e = DAT_001e + -1, DAT_001e != '\0')) goto LAB_0282;
  DAT_004c = '\x01';
LAB_0292:
  ProcessData();
  return;
}


// Process Data


/* WARNING: Instruction at (RAM,0x0296) overlaps instruction at (RAM,0x0295)
    */
/* WARNING: Control flow encountered bad instruction data */

byte ProcessData(void)

{
  byte bVar1;
  byte bVar2;
  byte bVar3;
  byte bVar4;
  char cVar5;
  byte bVar6;
  bool bVar7;
  byte bVar8;
  
  if ((DAT_0020 & 8) == 0) {
    DAT_0014 = DAT_0014 & 0x7f;
  }
  else {
    DAT_0014 = DAT_0014 | 0x80;
  }
  PORTC = PORTC & 0xfd;
  bVar3 = PORTA;
  if (PORTA == DAT_0012) {
    DAT_0013 = DAT_0013 + -1;
    if (DAT_0013 == '\0') {
      DAT_0017 = PORTA ^ DAT_0015;
      if ((DAT_0017 & 0x40) == 0) {
        bVar2 = DAT_0012 & 0x3f;
        if (bVar2 != 0) {
          DAT_0016 = bVar2;
          DAT_0011 = 'P';
          bVar6 = 0x80;
          if ((DAT_0014 & 0x10) == 0) goto LAB_0194;
code_r0x0192:
          bVar6 = 0x8b;
LAB_0194:
          bVar3 = *(byte *)(ushort)bVar6;
          if (bVar3 != bVar2) goto code_r0x0199;
          bVar8 = *(byte *)(ushort)(byte)(bVar6 + 1) >> 7;
          bVar6 = *(byte *)(ushort)(byte)(bVar6 + 1) << 1;
          bVar7 = bVar6 == 0;
          bVar4 = bVar3;
          bVar1 = DAT_004c;
          switch(bVar6) {
          case 0:
            bVar3 = switchD_01a4::caseD_34();
            return bVar3;
          case 2:
            bVar3 = switchD_01a4::caseD_2a();
            return bVar3;
          case 4:
            bVar3 = switchD_01a4::caseD_46();
            return bVar3;
          case 6:
            bVar3 = switchD_01a4::caseD_56();
            return bVar3;
          case 8:
            bVar3 = switchD_01a4::caseD_5a();
            return bVar3;
          case 10:
            goto switchD_01a4_caseD_a;
          case 0xc:
            bVar3 = switchD_01a4::caseD_6c();
            return bVar3;
          case 0xe:
            break;
          case 0x10:
            goto code_r0x01b7;
          case 0x12:
            goto switchD_01a4_caseD_12;
          case 0x14:
            goto switchD_01a4_caseD_14;
          case 0x16:
            goto switchD_01a4_caseD_16;
          case 0x18:
            goto switchD_01a4_caseD_18;
          case 0x1a:
            if ((DAT_0038 & 2) != 0) goto code_r0x0191;
            if ((DAT_0038 & 2) == 0) goto switchD_01a4_caseD_20;
            goto code_r0x017d;
          case 0x1c:
            goto switchD_01a4_caseD_1c;
          case 0x1e:
            CHAR_D_00b6 = CHAR_D_00b6 << 1;
            bVar7 = CHAR_D_00b6 == '\0';
          case 0x20:
switchD_01a4_caseD_20:
            CHAR_ _00cd = CHAR_ _00cd | 4;
switchD_01a4_caseD_22:
            if ((DAT_003c & 2) == 0) {
              if ((CHAR_D_00b7 & 1U) != 0) goto switchD_01a4_caseD_28;
            }
            else {
code_r0x0199:
              bVar7 = bVar3 == 0xff;
            }
            if (bVar7) goto LAB_01ce;
            bVar6 = bVar6 + 2;
            goto LAB_0194;
          case 0x22:
            goto switchD_01a4_caseD_22;
          case 0x24:
            goto switchD_01a4_caseD_24;
          case 0x26:
            CHAR_"_00cc = bVar3;
          case 0x28:
switchD_01a4_caseD_28:
            if ((DAT_001f & 1) == 0) {
                    /* WARNING: Read-only address (RAM,0x00e8) is written */
              uRAM00e8 = 0x12;
code_r0x01de:
              FUN_0238(2);
switchD_01a4_caseD_3c:
              FUN_0238();
              switchD_01a4::caseD_a4();
switchD_01a4_caseD_42:
              bVar3 = 4;
switchD_01a4_caseD_44:
              bVar3 = FUN_01c0(bVar3);
              return bVar3;
            }
            Not_Used = Not_Used | 4;
code_r0x01d4:
            if ((DAT_0020 & 8) != 0) goto LAB_01c6;
            break;
          case 0x2a:
            if ((DAT_0014 & 0x10) != 0) break;
            goto code_r0x01d4;
          case 0x2c:
            if ((DDRC & 2) == 0) goto code_r0x01f6;
            *(byte *)(bVar6 + 0xa6) = bVar6;
            if ((DAT_0020 & 1) != 0) goto code_r0x01db;
            goto code_r0x01c0;
          case 0x2e:
            goto LAB_01c6;
          case 0x32:
            goto switchD_01a4_caseD_32;
          case 0x34:
code_r0x01db:
            if ((DAT_0012 & 0x80) == 0) goto code_r0x01de;
            goto LAB_01c6;
          case 0x36:
            goto switchD_01a4_caseD_36;
          case 0x38:
            goto switchD_01a4_caseD_38;
          case 0x3a:
            if ((DAT_0038 & 2) != 0) {
switchD_01a4_caseD_a:
              bVar3 = switchD_01a4::caseD_5e();
              return bVar3;
            }
            goto code_r0x01e4;
          case 0x3c:
            goto switchD_01a4_caseD_3c;
          case 0x3e:
            CHAR_ _00cd = CHAR_ _00cd << 1;
          case 0x40:
            goto switchD_01a4_caseD_40;
          case 0x42:
            goto switchD_01a4_caseD_42;
          case 0x44:
            goto switchD_01a4_caseD_44;
          case 0x46:
            goto code_r0x01ed;
          case 0x48:
            goto switchD_01a4_caseD_48;
          case 0x4a:
            bVar8 = (byte)CHAR_ _00cd >> 7;
            CHAR_ _00cd = CHAR_ _00cd << 1;
          case 0x4c:
            if ((CHAR_D_00b7 & 1U) == 0) goto switchD_01a4_caseD_1c;
code_r0x01f6:
            if ((DAT_0038 & 2) == 0) goto switchD_01a4_caseD_52;
            goto LAB_01c6;
          case 0x4e:
            goto switchD_01a4_caseD_4e;
          case 0x50:
            bVar8 = (byte)CHAR_ _00cd >> 7;
            CHAR_ _00cd = CHAR_ _00cd << 1;
          case 0x52:
switchD_01a4_caseD_52:
            if ((bRAM004b & 2) == 0) {
              bVar3 = bVar3 + cRAMa604 + bVar8;
switchD_01a4_caseD_58:
              bVar3 = FUN_01c0(bVar3);
              return bVar3;
            }
            if ((DAT_0026 & 1) == 0) goto switchD_01a4_caseD_78;
            goto code_r0x0213;
          case 0x56:
            bVar3 = 4;
          case 0x58:
            goto switchD_01a4_caseD_58;
          case 0x5a:
            bVar3 = 8;
          case 0x5c:
            bVar3 = FUN_01c0(bVar3);
            return bVar3;
          case 0x5e:
            if ((DAT_0015 & 0x40) != 0) {
              if ((DAT_0014 & 0x20) != 0) goto switchD_01a4_caseD_68;
              goto switchD_01a4_caseD_64;
            }
            goto LAB_01c6;
          case 0x60:
          case 0x62:
            DDRA = DDRA | 4;
          case 100:
switchD_01a4_caseD_64:
            DAT_0014 = DAT_0014 | 0x20;
            goto LAB_01c6;
          case 0x68:
switchD_01a4_caseD_68:
            DAT_0014 = DAT_0014 & 0xdf;
          case 0x6a:
            goto LAB_01c6;
          case 0x6c:
            goto code_r0x0213;
          case 0x6e:
            goto switchD_01a4_caseD_6e;
          case 0x70:
            goto switchD_01a4_caseD_70;
          case 0x72:
            goto switchD_01a4_caseD_72;
          case 0x74:
            goto switchD_01a4_caseD_74;
          case 0x76:
            goto switchD_01a4_caseD_76;
          case 0x78:
            goto switchD_01a4_caseD_78;
          case 0x7a:
          case 0x7c:
            DDRA = DDRA | 4;
          case 0x7e:
            goto switchD_01a4_caseD_7e;
          case 0x82:
            goto switchD_01a4_caseD_82;
          case 0x86:
            goto switchD_01a4_caseD_86;
          case 0x88:
            if ((DAT_0018 & 4) != 0) {
              bVar3 = (*(code *)(ushort)bVar6)();
switchD_01a4_caseD_a0:
              while (bVar3 = bVar3 - 1, bVar3 != 0) {
LAB_0244:
                do {
                  bVar6 = bVar6 - 1;
                  bVar7 = bVar6 == 0;
switchD_01a4_caseD_9e:
                } while (!bVar7);
              }
                    /* WARNING: Read-only address (RAM,0x00e8) is written */
              return 0;
            }
            goto LAB_01c6;
          case 0x8a:
            DAT_0020 = DAT_0020 | 4;
          case 0x8c:
            uRAM00e8 = 0x12;
                    /* WARNING: Bad instruction - Truncating control flow here */
            halt_baddata();
          case 0x8e:
            DAT_0020 = DAT_0020 | 4;
          case 0x90:
            bVar3 = (bVar3 | DAT_0014) & 0x7f;
code_r0x023c:
            PORTC = PORTC & 0xfe;
            PORTB = bVar3;
code_r0x0240:
            PORTC = PORTC | 1;
code_r0x0242:
            bVar3 = 0x20;
            goto LAB_0244;
          case 0x92:
            CHAR_"_00a4 = CHAR_"_00a4 | 4;
          case 0x94:
            *(undefined *)(ushort)bVar6 = 0;
            goto code_r0x023c;
          case 0x96:
            if ((CHAR_D_00b7 & 2U) != 0) goto switchD_01a4_caseD_9a;
            goto code_r0x0240;
          case 0x98:
            if ((DAT_0010 & 1) == 0) goto LAB_0244;
            goto code_r0x0242;
          case 0x9a:
switchD_01a4_caseD_9a:
            if ((CHAR_ _00a6 & 2U) == 0) goto LAB_0244;
            goto LAB_0266;
          case 0x9c:
            goto switchD_01a4_caseD_f8;
          case 0x9e:
            goto switchD_01a4_caseD_9e;
          case 0xa0:
            goto switchD_01a4_caseD_a0;
          case 0xa2:
            DAT_0011 = 0x50;
            DAT_0016 = bVar2;
            uRAM00e8 = 0x12;
            return bVar3 | *(byte *)(ushort)bVar6;
          case 0xa4:
            bVar3 = 6;
          case 0xa6:
            DAT_001e = bVar3;
switchD_01a4_caseD_a8:
            bVar3 = 0x30;
switchD_01a4_caseD_aa:
            DAT_004c = bVar3;
switchD_01a4_caseD_ac:
            do {
              do {
                do {
                  bVar6 = bVar6 - 1;
                } while (bVar6 != 0);
code_r0x0256:
                bVar3 = bVar3 - 1;
                bVar7 = bVar3 == 0;
switchD_01a4_caseD_b0:
              } while (!bVar7);
switchD_01a4_caseD_b2:
              DAT_001e = DAT_001e - 1;
              bVar7 = DAT_001e == 0;
switchD_01a4_caseD_b4:
            } while (!bVar7);
switchD_01a4_caseD_b6:
            return bVar3;
          case 0xa8:
            goto switchD_01a4_caseD_a8;
          case 0xaa:
            goto switchD_01a4_caseD_aa;
          case 0xac:
            goto switchD_01a4_caseD_ac;
          case 0xae:
            bVar3 = (*(code *)(ushort)bVar6)();
            goto code_r0x0256;
          case 0xb0:
            goto switchD_01a4_caseD_b0;
          case 0xb2:
            goto switchD_01a4_caseD_b2;
          case 0xb4:
            goto switchD_01a4_caseD_b4;
          case 0xb6:
            goto switchD_01a4_caseD_b6;
          case 0xb8:
            CHAR_D_00b7 = CHAR_D_00b7 | 4;
          case 0xba:
            goto LAB_0266;
          case 0xbc:
            bVar4 = Timer_Data_Reg;
            if ((CHAR_D_00b7 & 1U) != 0) goto code_r0x026e;
            goto LAB_0266;
          case 0xbe:
            bVar3 = PORTA;
            if ((DAT_002f & 0x10) == 0) goto code_r0x026a;
            goto LAB_0272;
          case 0xc0:
            goto code_r0x026a;
          case 0xc2:
            if ((CHAR_"_00a4 & 1U) == 0) goto code_r0x026c;
            bVar2 = bVar3;
            if ((DAT_001f & 2) != 0) goto code_r0x02cf;
            goto LAB_02ae;
          case 0xc4:
            CHAR_A_00a1 = '\0';
          case 0xc6:
            bVar4 = Timer_Data_Reg;
            if ((DAT_0027 & 1) == 0) goto LAB_0292;
            goto LAB_0266;
          case 200:
            bVar3 = *(byte *)(ushort)bVar6;
            goto LAB_0292;
          case 0xca:
            goto switchD_01a4_caseD_72;
          case 0xcc:
            bVar1 = bVar3;
            if ((CHAR_D_00b7 & 1U) == 0) goto code_r0x0276;
            goto LAB_0292;
          case 0xce:
            DAT_0012 = DAT_0012 | 0x20;
          case 0xd0:
            goto code_r0x027a;
          case 0xd2:
            if ((DAT_0010 & 2) == 0) goto code_r0x027c;
            goto code_r0x027e;
          case 0xd4:
            if ((CHAR_D_00b6 & 2U) != 0) goto code_r0x02ca;
            goto code_r0x027e;
          case 0xd6:
            bVar4 = bVar3 + 1;
            goto code_r0x027e;
          case 0xd8:
            CHAR_ _00a6 = CHAR_ _00a6 | 0x80;
          case 0xda:
            if ((DAT_002e & 4) != 0) goto code_r0x0284;
            goto switchD_01a4_caseD_ee;
          case 0xdc:
            bRAM005a = bRAM005a & 0xfe;
          case 0xde:
            goto switchD_01a4_caseD_de;
          case 0xe0:
            goto switchD_01a4_caseD_e0;
          case 0xe2:
            bVar3 = bVar3 ^ *(byte *)(ushort)bVar6;
            goto code_r0x028a;
          case 0xe4:
            DAT_0026 = DAT_0026 | 0x80;
          case 0xe6:
            goto code_r0x028e;
          case 0xe8:
            if ((CHAR_D_00b7 & 1U) != 0) goto LAB_0292;
            goto code_r0x02de;
          case 0xea:
            bVar3 = bVar3 + 1;
            goto LAB_0292;
          case 0xec:
            if ((bRAM0042 & 1) == 0) goto LAB_0244;
            goto switchD_01a4_caseD_f2;
          case 0xee:
            goto switchD_01a4_caseD_ee;
          case 0xf0:
            goto switchD_01a4_caseD_f0;
          case 0xf2:
            goto switchD_01a4_caseD_f2;
          case 0xf4:
            goto switchD_01a4_caseD_f4;
          case 0xf6:
            goto switchD_01a4_caseD_f6;
          case 0xf8:
            goto switchD_01a4_caseD_f8;
          case 0xfa:
            goto switchD_01a4_caseD_fa;
          case 0xfc:
            goto switchD_01a4_caseD_fc;
          case 0xfe:
            goto switchD_01a4_caseD_fe;
          }
          bVar3 = 1;
switchD_01a4_caseD_32:
          bVar3 = FUN_01c0(bVar3);
          return bVar3;
        }
      }
      else {
        bVar3 = Timer_Data_Reg;
        if ((DAT_0012 & 0x40) == 0) {
          DAT_0014 = DAT_0014 | 0x60;
        }
        else {
code_r0x017d:
          if (bVar3 == 0) {
            DAT_0014 = DAT_0014 | 0x20;
          }
          else {
            DAT_0014 = DAT_0014 & 0xdf;
          }
        }
      }
      DAT_0015 = DAT_0012;
    }
  }
  else {
LAB_0125:
    DAT_0013 = '\x05';
    DAT_0012 = bVar3;
  }
  DAT_0010 = DAT_0010 - 1;
  if (((DAT_0010 == '\0') && (DAT_0011 = DAT_0011 + -1, DAT_0011 == '\0')) &&
     (DAT_0014 = DAT_0014 & 0xef, (DAT_0019 & 0x20) == 0)) {
    FUN_0618();
    DAT_0011 = '\x06';
  }
  bVar3 = WaitForData();
  return bVar3;
code_r0x026a:
  while( true ) {
    bVar3 = bVar3 & 0x3f;
code_r0x026c:
    bVar7 = bVar3 == 0;
code_r0x026e:
    bVar4 = Timer_Data_Reg;
    if (!bVar7) break;
LAB_0266:
    Timer_Data_Reg = bVar4;
    bVar7 = (bool)readIRQ();
    bVar3 = PORTA;
    if (bVar7) goto LAB_0272;
  }
  goto LAB_0292;
  while (DAT_001f = bVar3 + 1, bVar3 = DAT_001f, DAT_001f != 4) {
LAB_035f:
    bVar7 = DAT_001f == *(byte *)(bVar3 + 0x29);
    DAT_001f = bVar3;
    if (bVar7) break;
  }
  bVar3 = 4 - DAT_001f;
  do {
    if (DAT_0047 == '(') {
      DAT_0047 = '\0';
    }
    FUN_05fc(0x18);
    DAT_0047 = DAT_0047 + '\x01';
    FUN_0690(0x27);
    FUN_05d2(*(undefined *)(bVar3 + 0x25));
    bVar3 = bVar3 + 1;
  } while (bVar3 != 4);
  bVar3 = 0;
  do {
    *(undefined *)(bVar3 + 0x29) = *(undefined *)(bVar3 + 0x25);
    bVar3 = bVar3 + 1;
  } while (bVar3 != 4);
  goto joined_r0x0356;
switchD_01a4_caseD_36:
  bVar3 = bVar3 ^ *(byte *)(bVar6 + 0xa6);
switchD_01a4_caseD_38:
  if ((CHAR_ _00cd & 2U) == 0) {
    CHAR_ _00cd = CHAR_ _00cd << 1;
  }
code_r0x01e4:
  if ((DAT_0038 & 2) != 0) {
    uRAM00e8 = 0x12;
                    /* WARNING: Bad instruction - Truncating control flow here */
    halt_baddata();
  }
switchD_01a4_caseD_40:
  if ((bRAM004b & 2) == 0) goto code_r0x01ea;
  PORTC = PORTC | 4;
  goto code_r0x0192;
code_r0x01ea:
  if ((DAT_0020 & 4) == 0) {
code_r0x01ed:
    bVar3 = 2;
switchD_01a4_caseD_48:
    FUN_0238(bVar3);
    switchD_01a4::caseD_10();
switchD_01a4_caseD_4e:
    FUN_0238();
    switchD_01a4::caseD_a4();
  }
  else {
code_r0x01c0:
    FUN_0238(bVar3);
switchD_01a4_caseD_1c:
    FUN_0238();
  }
  goto LAB_01c6;
switchD_01a4_caseD_86:
  if ((DAT_0014 & 0x10) == 0) {
    DAT_0014 = DAT_0014 | 0x10;
  }
  else {
    DAT_0014 = DAT_0014 & 0xef;
  }
  goto LAB_01c6;
code_r0x0191:
  if ((CHAR_ _00ae & 2U) != 0) {
    bVar3 = DAT_0012 & 0xc0;
    DAT_0015 = bVar3;
    goto LAB_0125;
  }
  goto LAB_0194;
code_r0x01b7:
  do {
    bVar3 = PORTA;
switchD_01a4_caseD_12:
    bVar3 = bVar3 & 0x3f;
switchD_01a4_caseD_14:
    bVar7 = bVar3 == 0;
switchD_01a4_caseD_16:
  } while (!bVar7);
switchD_01a4_caseD_18:
  uRAM00e8 = 0x12;
  return bVar3;
switchD_01a4_caseD_ee:
  bVar6 = 8;
switchD_01a4_caseD_f0:
  do {
    do {
      bVar3 = PORTA;
switchD_01a4_caseD_f2:
      PORTC = PORTC & 0xfd;
switchD_01a4_caseD_f4:
      PORTC = PORTC | 2;
switchD_01a4_caseD_f6:
      DAT_0020 = bVar3;
switchD_01a4_caseD_f8:
      DAT_0021 = DAT_0021 >> 1;
switchD_01a4_caseD_fa:
      DAT_0022 = DAT_0022 >> 1;
switchD_01a4_caseD_fc:
      DAT_0023 = DAT_0023 >> 1;
switchD_01a4_caseD_fe:
      if ((DAT_0020 & 1) == 0) {
        DAT_0021 = DAT_0021 | 0x80;
      }
      else {
        DAT_0021 = DAT_0021 & 0x7f;
      }
LAB_02ae:
      if ((DAT_0020 & 2) == 0) {
        DAT_0022 = DAT_0022 | 0x80;
      }
      else {
        DAT_0022 = DAT_0022 & 0x7f;
      }
      if ((DAT_0020 & 4) == 0) {
        DAT_0023 = DAT_0023 | 0x80;
      }
      else {
        DAT_0023 = DAT_0023 & 0x7f;
      }
      DAT_001a = DAT_001a + 1;
    } while (DAT_001a != 8);
    bVar3 = 0;
code_r0x02ca:
    bVar6 = bVar6 - 1;
    bVar2 = DAT_0021;
    DAT_001a = bVar3;
code_r0x02cf:
    *(byte *)(bVar6 + 0x2d) = bVar2;
    *(byte *)(bVar6 + 0x35) = DAT_0022;
    *(byte *)(bVar6 + 0x3d) = DAT_0023;
  } while (bVar6 != 0);
code_r0x02de:
  if (DAT_0019 != DAT_0018) {
    DAT_0018 = DAT_0019;
    FUN_0618();
    DAT_0047 = '\0';
  }
  DAT_0019 = 0;
  DAT_001b = DAT_002d;
  DAT_001c = DAT_002e;
  cVar5 = FUN_0641();
  DAT_001d = cVar5;
  if (cVar5 == '\0') {
    bVar3 = FUN_041d();
    return bVar3;
  }
  bVar3 = 0;
  DAT_001f = 1;
  while( true ) {
    *(char *)((bVar3 >> 1) + 0x25) = cVar5;
    DAT_001b = *(undefined *)((byte)(DAT_001f + 1) + 0x2d);
    bVar3 = DAT_001f + 2;
    if (bVar3 == 9) break;
    DAT_001c = *(byte *)(bVar3 + 0x2d);
    cVar5 = FUN_0641();
  }
  if ((DAT_0018 & 0x20) == 0) {
    bVar3 = 3;
    do {
      *(char *)(bVar3 + 0x29) = *(char *)(bVar3 + 0x25);
      if (*(char *)(bVar3 + 0x25) != ' ') {
        DAT_0045 = 0;
        FUN_0690(0x40);
        goto LAB_03ab;
      }
      bVar3 = bVar3 - 1;
    } while (-1 < (char)bVar3);
    DAT_0047 = '\0';
    DAT_0045 = 0x60;
    DAT_0019 = DAT_0019 | 0x20;
  }
  else {
    bVar3 = 3;
    DAT_0019 = DAT_0019 | 0x20;
    do {
      if (*(char *)(bVar3 + 0x25) != *(char *)(bVar3 + 0x29)) {
        DAT_001f = DAT_0025;
        bVar3 = 1;
        goto LAB_035f;
      }
      bVar3 = bVar3 - 1;
    } while (-1 < (char)bVar3);
  }
joined_r0x0356:
  if ((DAT_003a & 0x80) != 0) {
    FUN_0690(0x40);
    FUN_060c();
    DAT_001f = 0;
    FUN_0623(DAT_0035);
    FUN_05d2();
    FUN_0623(*(undefined *)(DAT_001f + 0x35));
    FUN_05d2();
    if ((DAT_0038 & 0x80) != 0) {
      DAT_0019 = DAT_0019 | 0x10;
      FUN_060c();
    }
    FUN_0623(*(undefined *)(DAT_001f + 0x35));
    FUN_05d2();
    FUN_0623(*(undefined *)(DAT_001f + 0x35));
    FUN_05d2();
    if ((DAT_0038 & 0x80) == 0) {
      FUN_060c();
      bVar3 = DAT_001f + 2;
    }
    else {
      FUN_05d2(0x3a);
      FUN_0623(*(undefined *)(DAT_001f + 0x35));
      FUN_05d2();
      FUN_0623(*(undefined *)(DAT_001f + 0x35));
      FUN_05d2();
      FUN_05d2(0x3a);
      bVar3 = DAT_001f;
    }
    FUN_0623(*(undefined *)(bVar3 + 0x35));
    FUN_05d2();
    FUN_0623(*(undefined *)(DAT_001f + 0x35));
    FUN_05d2();
    FUN_0690(0x57);
    FUN_05d2(0x20);
    bVar3 = 0;
    do {
      DAT_001b = *(undefined *)(bVar3 + 0x3d);
      FUN_057c();
      bVar3 = bVar3 + 1;
    } while (bVar3 < 8);
    bVar3 = ProcessData();
    return bVar3;
  }
LAB_03ab:
  FUN_0690(DAT_0045);
  bVar3 = DAT_0019;
  DAT_0019 = DAT_0019 | 2;
  if ((bVar3 & 0x20) == 0) {
    if (DAT_0025 == 0x20) {
      FUN_060c();
    }
    else {
      FUN_060c();
    }
  }
  FUN_03cf(0x35);
  bVar3 = FUN_03f4();
  return bVar3;
LAB_0272:
  DAT_001a = 0;
code_r0x0276:
  PORTC = PORTC & 0xfe | 2;
code_r0x027a:
  PORTC = PORTC | 1;
code_r0x027c:
  bVar4 = DAT_004c;
code_r0x027e:
  bVar3 = 5;
  DAT_001e = bVar4;
  do {
    do {
      do {
        cVar5 = readIRQ();
        if (cVar5 == '\0') goto switchD_01a4_caseD_ee;
code_r0x0284:
        bVar6 = bVar6 - 1;
        bVar7 = bVar6 == 0;
switchD_01a4_caseD_de:
      } while (!bVar7);
switchD_01a4_caseD_e0:
      bVar3 = bVar3 - 1;
    } while (bVar3 != 0);
code_r0x028a:
    DAT_001e = DAT_001e - 1;
  } while (DAT_001e != 0);
code_r0x028e:
  bVar3 = 1;
  bVar1 = bVar3;
LAB_0292:
  DAT_004c = bVar1;
  bVar3 = ProcessData(bVar3);
  return bVar3;
switchD_01a4_caseD_74:
  while( true ) {
    bVar7 = bVar3 == 0;
switchD_01a4_caseD_76:
    if (bVar7) break;
code_r0x0213:
    bVar3 = PORTA;
switchD_01a4_caseD_6e:
    bVar3 = bVar3 & 0x3f;
switchD_01a4_caseD_70:
    bVar7 = bVar3 == 0x21;
switchD_01a4_caseD_72:
    if (bVar7) goto switchD_01a4_caseD_86;
  }
switchD_01a4_caseD_78:
  if ((DAT_0015 & 0x40) != 0) {
    if ((DAT_0014 & 0x40) == 0) {
switchD_01a4_caseD_7e:
      DAT_0014 = DAT_0014 | 0x40;
    }
    else {
switchD_01a4_caseD_82:
      DAT_0014 = DAT_0014 & 0xbf;
    }
  }
LAB_01c6:
  FUN_023c(DAT_0014);
switchD_01a4_caseD_24:
  switchD_01a4::caseD_10();
LAB_01ce:
  bVar3 = FUN_011f();
  return bVar3;
}


