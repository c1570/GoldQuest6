#!/bin/bash
set -o errexit

DBUILD=$(pwd)/build
DCWD=$(pwd)
GQLANG=${GQLANG:-de}
mkdir -p build

echo "*** Building docs using Crank the PRINT"
# just build the HTML, ignoring other CtP output
(cp "gq6_$GQLANG.prg" "$DBUILD/input.prg" ; cp -a labels.csv "$DBUILD/" ; cd "$DBUILD" ; "$DCWD/../cranktheprint/cranktheprint") > /dev/null
perl -i -pe 's/<body>/<body><a href="https:\/\/github.com\/c1570\/GoldQuest6">Back to Gold Quest 6 GitHub page<\/a><br\/><small>Using font by <a href="https:\/\/style64.org\/c64-truetype">Style<\/a><\/small><br\/>/gm' "$DBUILD/output.html"
cp "$DBUILD/output.html" "$DCWD/docs/gq6_$GQLANG.html"

echo "*** Optimizations for Blitz"
echo "Input PRG length: $(stat -c%s gq6_$GQLANG.prg) bytes"
petcat -o "$DBUILD/input.txt" "gq6_$GQLANG.prg"
# integer optimizations
perl -i -pe 's/ii/ii%/gm' "$DBUILD/input.txt"
perl -i -pe 's/jj/jj%/gm' "$DBUILD/input.txt"
# Blitz compile time is RAM limited. Remove some things that are not necessary for the full PRG.
perl -i -pe 's/^.*distremove.*//gm' "$DBUILD/input.txt"
perl -i -pe 's/:rem.*$//gm' "$DBUILD/input.txt"
perl -i -pe 's/^(\s*[0-9]*\s*)rem.*$/\1:/gm' "$DBUILD/input.txt"
petcat -w2 -o "$DBUILD/input.prg" "$DBUILD/input.txt"
echo "Optimized PRG length: $(stat -c%s $DBUILD/input.prg) bytes"

echo "*** Running Crank the PRINT"
# will generate output.prg and table_* files
(cp -a labels.csv "$DBUILD/" ; cd "$DBUILD" ; "$DCWD/../cranktheprint/cranktheprint" ; petcat -o ctp_output.txt output.prg ; mv output.prg ctp_output.prg)
if grep "sysq," "$DBUILD/ctp_output.txt"; then echo "CtP failed - some sysq still remains. Please check."; exit 1; fi
echo "CtP output PRG length: $(stat -c%s $DBUILD/ctp_output.prg) bytes"

echo "*** Building Crank the PRINT helper"
# xa65: https://www.floodgap.com/retrotech/xa/
xa ../cranktheprint/ctp_asm.a65 -o "$DBUILD/ctp_asm.prg"

echo "*** Running Blitz! compiler"
# Blitz cross compiler: https://csdb.dk/release/?id=173267
BOUT=$(./blitz_xc -o"$DBUILD/output_blitzed.prg" "$DBUILD/ctp_output.prg" 2>&1)
echo "$BOUT"
if ! echo "$BOUT" | grep -q "errors: 0"; then
  echo "Blitz! failed"
  exit 1
fi
petcat -o "$DBUILD/output_blitzed.xref.txt" "$DBUILD/output_blitzed.prg.xref" && rm -f "$DBUILD/output_blitzed.prg.xref"
echo "Blitz output PRG length: $(stat -c%s $DBUILD/output_blitzed.prg) bytes"

cd "$DBUILD"

echo "*** Building complete memory image"
rm -f mem_complete.bin
dd if=/dev/zero of=mem_complete.bin bs=1 count=65536
let OFF=0x0801 ; dd conv=notrunc if=output_blitzed.prg of=mem_complete.bin bs=1 skip=2 seek=$OFF
let OFF=0xA000 ; dd conv=notrunc if=table_a000.prg of=mem_complete.bin bs=1 skip=2 seek=$OFF
let OFF=0xB000 ; dd conv=notrunc if="$DCWD/music/gq6_music_dmc.prg" of=mem_complete.bin bs=1 skip=2 seek=$OFF
let OFF=0xC400 ; printf ' %.0s' {1..1000} | dd conv=notrunc of=mem_complete.bin bs=1 skip=0 seek=$OFF  # screen
let OFF=0xC800 ; dd conv=notrunc if=table_c800.prg of=mem_complete.bin bs=1 skip=2 seek=$OFF
let OFF=0xCE00 ; dd conv=notrunc if=ctp_asm.prg of=mem_complete.bin bs=1 skip=2 seek=$OFF
let OFF=0xCF00 ; dd conv=notrunc if="$DCWD/music/player.prg" of=mem_complete.bin bs=1 skip=2 seek=$OFF
let OFF=0xD000 ; dd conv=notrunc if="$DCWD/charsets.prg" of=mem_complete.bin bs=1 skip=2 seek=$OFF
let OFF=0xE000 ; dd conv=notrunc if=table_e000.prg of=mem_complete.bin bs=1 skip=2 seek=$OFF
echo -n -e "\x01\x08" > mem_basicstart.prg
let OFF=0x0801 ; dd if=mem_complete.bin of=mem_basicstart.prg bs=1 skip=$OFF seek=2

if [ -e "$DCWD/dali" ]; then
  echo "*** Running Dali compressor (PRG without Koala title)"
  # Dali compressor: https://github.com/bboxy/bitfire/tree/master/packer/dali
  "$DCWD/dali" -o "gq6_no_title_$GQLANG.prg" --sfx 2076 --01 55 --cli mem_basicstart.prg
  echo "Created gq6_no_title_$GQLANG.prg"
else
  echo "*** Dali not installed, skipping"
fi

echo "*** Building PRG with Koala title"
# this is adapted from https://github.com/c1570/MrVSFUnfreeze
let OSTART=0x0801 ; let OLEN=0x5680; dd if=mem_complete.bin of=mem_08.bin bs=1 skip=$OSTART count=$OLEN
let OSTART=0x5E80 ; let OLEN=0x3580; dd if=mem_complete.bin of=mem_60.bin bs=1 skip=$OSTART count=$OLEN
let OSTART=0xA000 ; let OLEN=0x5FF0; dd if=mem_complete.bin of=mem_A0.bin bs=1 skip=$OSTART count=$OLEN

dd conv=notrunc if="$DCWD/pics/gq6_pic_$GQLANG.prg" of=koa_bitmap.bin bs=1 skip=2 count=8000
dd conv=notrunc if="$DCWD/pics/gq6_pic_$GQLANG.prg" of=koa_screen.bin bs=1 skip=8002 count=1000
dd conv=notrunc if="$DCWD/pics/gq6_pic_$GQLANG.prg" of=koa_colmem.bin bs=1 skip=9002 count=1000

echo "*** Running LZSA compressor"
# LZSA compressor: https://github.com/emmanuel-marty/lzsa
rm -f cmpr_*.bin
"$DCWD/lzsa" -stats -f 1 -m 3 -r mem_08.bin cmpr_08.bin
"$DCWD/lzsa" -stats -f 1 -m 5 -r mem_60.bin cmpr_60.bin
"$DCWD/lzsa" -stats -f 1 -m 5 -r mem_A0.bin cmpr_A0.bin
"$DCWD/lzsa" -stats -f 1 -m 5 -r koa_bitmap.bin cmpr_bitmap.bin
"$DCWD/lzsa" -stats -f 1 -m 5 -r koa_screen.bin cmpr_screen.bin
"$DCWD/lzsa" -stats -f 1 -m 5 -r koa_colmem.bin cmpr_colmem.bin
ls -la cmpr_*.bin

echo "*** Assembling PRG file"
cd "$DCWD"
acme -o "build/gq6_title_$GQLANG.prg" -f cbm prg_with_title.asm
echo "Built gq6_title_$GQLANG.prg"
