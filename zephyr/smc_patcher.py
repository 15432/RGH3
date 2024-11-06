import struct

def patch(data, offset, new):
    return data[:offset] + new + data[offset + len(new):]

def lcall(offset):
    return b"\x12" + struct.pack(">H", offset)

def ljmp(offset):
    return b"\x02" + struct.pack(">H", offset)

INIT_START = 0x1376
CODE_START = 0x2C5F

init_bin = open("init.bin", "rb").read()[INIT_START:]
code_bin = open("code.bin", "rb").read()[CODE_START:]

smc = open("zephyr_clean.bin", "rb").read()

# error processing patches
smc = patch(smc, 0x1244, ljmp(0x126E)) # go reboot on no_handshake

# GPIO patches
smc = patch(smc, 0x118b, b'\x80') # skip GPU check 1
smc = patch(smc, 0x11b6, b'\x80') # skip GPU check 2
smc = patch(smc, 0x22B4, b'\x00' * 3) # skip setting DBG as input
smc = patch(smc, 0x22B9, b'\xc2') # skip reading dbg_led

# keep UART enabled
smc = patch(smc, 0x2323 + 2, b'\xC0')

# stack move patches
smc = patch(smc, 0x758, b'\x80')
smc = patch(smc, 0x777, b'\x80')

# main calls hijack
smc = patch(smc, CODE_START, code_bin)  # place main code

rom_end = 0x2FF0                        # there we'll place call stubs

for pos in range(0x7a4, 0x7e6, 3):
    if pos == 0x7c2:                    # remove dbg LED FSM
        smc = patch(smc, pos, b"\x00" * 3)
        continue
    orig_addr = struct.unpack(">H", smc[pos+1:pos+3])[0]
    my_call = lcall(CODE_START) + ljmp(orig_addr)
    rom_end -= len(my_call)
    smc = patch(smc, rom_end, my_call)
    smc = patch(smc, pos, lcall(rom_end))

# i2c re-arrange
CUT_START = 0x2924
CUT_END   = 0x294E
CUT_LEN   = CUT_END - CUT_START
smc = patch(smc, rom_end - CUT_LEN, smc[CUT_START:CUT_END])
rom_end -= CUT_LEN
# delay
for off in [0x2597, 0x259D, 0x25DF, 0x25E4, 0x2953, 0x2958]:
    smc = patch(smc, off, lcall(rom_end))
# line status
smc = patch(smc, 0x25D1, lcall(rom_end + 0x10))
smc = patch(smc, 0x295B, lcall(rom_end + 0x10))
# hw trigger
smc = patch(smc, 0x25E7, lcall(rom_end + 0x14))

#               IN  W   CE=[x8  E8  40  14] W   D4=[09  90  e0  xx] EX
slow_data = b"\x00\x0B\xCE\x28\xE8\x40\x14\x0B\xD4\x09\x90\xE0\x1E\x03"
fast_data = b"\x00\x0B\xCE\x08\xE8\x40\x14\x0B\xD4\x09\x90\xE0\x0E\x03"
smc  = patch(smc, CUT_START, slow_data + fast_data)

# pre-main init code
smc = patch (smc, INIT_START, init_bin + ljmp(0x253A))
smc = patch (smc, 0x770, lcall(INIT_START))

open("smc.bin", "wb").write(smc)
