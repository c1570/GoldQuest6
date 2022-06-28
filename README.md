# Gold Quest VI
https://github.com/c1570/GoldQuest6  
https://www.c64-wiki.de/wiki/Gold_Quest_VI  
https://csdb.dk/release/?id=218974

A C64 dungeon crawler written in 99.9% BASIC V2 (with added dwarves).

You can run the plain PRGs using [Paradoxon Basic](https://github.com/c1570/ParadoxonBasicCRT) (without music and charsets then).

Generated code documentation see [docs/gq6_en.html](https://c1570.github.io/GoldQuest6/gq6_en.html) and [docs/gq6_de.html](https://c1570.github.io/GoldQuest6/gq6_de.html).

The full game (including music etc., without the need for Paradoxon) can be built using [make.sh](make.sh).

You will need [xa65](https://www.floodgap.com/retrotech/xa/), [Crank the PRINT!](https://github.com/c1570/CrankThePRINT), the cross compiler version of the [Blitz!](https://csdb.dk/release/?id=173267) basic compiler, and the [Dali compressor](https://github.com/bboxy/bitfire/tree/master/packer/dali) for the simple build.

For the build including the Koala title screen, you need [LZSA1](https://github.com/emmanuel-marty/lzsa) and the [ACME assembler](http://sourceforge.net/projects/acme-crossass/).

For building a CRT, use [Mr. V. S. F. Unfreeze](https://github.com/c1570/MrVSFUnfreeze).
Build the VSF by loading the PRG in VICE, enter monitor during LOAD, `until 081c` (run until decompression has finished), `> ba 0` (set device ID to 0), `watch 030c`, `x` (run until the title screen gets printed), then `dump "freeze.vsf"`.

The memory layout will be as following.

* $0801-$9FFF BASIC/Blitz!
* $A000-$AFFF Crank the PRINT strings (part 2)
* $B000-$C3xx Music
* $C400-$C7FF Screen memory
* $C800-$CDFF Crank the PRINT strings (part 3)
* $CE00 Crank the PRINT helper
* $CF00 Music helper
* $D000 Charset 1
* $D800 Charset 2
* $E000-$FFF0 Crank the PRINT strings (part 1)
