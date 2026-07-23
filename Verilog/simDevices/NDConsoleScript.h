/**************************************************************************
** NDConsoleScript - runtime-configurable OPCOM console command script    **
**                                                                        **
** Resolves the console command-injection string the ND120 harness types  **
** into the monitor once OPCOM is up, at RUN TIME instead of compile time. **
**                                                                        **
** WHY THIS EXISTS (architectural, not a hack):                           **
**   The old path was a compile-time macro `SCRIPT_CMD`. Driving an        **
**   arbitrary sequence (e.g. an OPCOM deposit/examine memory test) that   **
**   way means passing a string full of `\r` through make -> Verilator     **
**   -CFLAGS. That quoting is fragile and, worse, adding `-DSCRIPT_CMD=..` **
**   or `-include ...` to EXTRA_CFLAGS collides with Verilator's           **
**   precompiled-header build (VND120_TOP__pch.h.fast: No such file).      **
**   So every ad-hoc console test needed a full rebuild AND kept breaking  **
**   the PCH. Making the script a RUNTIME input removes both problems and  **
**   is reusable for ANY future monitor-driven test (boot, deposit,        **
**   examine, register pokes, ...) with no recompile.                      **
**                                                                        **
** Precedence (first match wins):                                         **
**   1. env ND120_SCRIPT       - inline string; C escapes \r \n \t \\ \e   **
**                               \0 (octal \NNN too) are decoded to bytes. **
**   2. env ND120_SCRIPT_FILE  - path to a file; its RAW bytes ARE the     **
**                               script (a file can hold real CRs, so no   **
**                               escaping is needed there).                **
**   3. the compiled-in default (the `fallback` the caller passes, i.e.    **
**      the existing SCRIPT_CMD) - so default behaviour is unchanged.      **
***************************************************************************/

#ifndef ND_CONSOLE_SCRIPT_H
#define ND_CONSOLE_SCRIPT_H

// Resolve the effective console script. Returns a pointer that is valid for
// the whole run (either the caller's fallback, or a buffer owned by this
// module). Callers MUST NOT free it. Never returns NULL (worst case it hands
// back the fallback). Emits ONE informational line to stderr naming the source.
const char *nd_console_script_resolve(const char *fallback);

#endif // ND_CONSOLE_SCRIPT_H
