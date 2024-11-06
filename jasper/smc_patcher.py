import struct

def patch(data, offset, new):
    return data[:offset] + new + data[offset + len(new):]

def lcall(offset):
    return b"\x12" + struct.pack(">H", offset)

def ljmp(offset):
    return b"\x02" + struct.pack(">H", offset)

INIT_START = 0x13ce
CODE_START = 0x2d73

init_bin = open("init.bin", "rb").read()[INIT_START:]
code_bin = open("code.bin", "rb").read()[CODE_START:]

smc = open("jasper_clean.bin", "rb").read()

# error processing patches
smc = patch(smc, 0x129E, ljmp(0x12D1)) # go reboot on no_handshake

# GPIO patches
smc = patch(smc, 0x11e3, b'\x80') # skip GPU check 1
smc = patch(smc, 0x120b, b'\x80') # skip GPU check 2
smc = patch(smc, 0x2359, b'\x00' * 3) # skip setting DBG as input
smc = patch(smc, 0x235e, b'\xc2') # skip reading dbg_led

# keep UART enabled
smc = patch(smc, 0x23ca, b'\xC0')

# stack move patches
smc = patch(smc, 0x758, b'\xBD')
smc = patch(smc, 0x777, b'\xBD')

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
CUT_START = 0x2a38
CUT_END   = 0x2a62
CUT_LEN   = CUT_END - CUT_START
smc = patch(smc, rom_end - CUT_LEN, smc[CUT_START:CUT_END])
rom_end -= CUT_LEN
# delay
for off in [0x2681, 0x2687, 0x26C9, 0x26CE, 0x2A67, 0x2A6C]:
    smc = patch(smc, off, lcall(rom_end))
# line status
smc = patch(smc, 0x26BB, lcall(rom_end + 0x10))
smc = patch(smc, 0x2A6F, lcall(rom_end + 0x10))
# hw trigger
smc = patch(smc, 0x26D1, lcall(rom_end + 0x14))

#               IN  W   CE=[x8  E8  40  14] W   D4=[09  90  e0  xx] EX
slow_data = b"\x00\x0B\xCE\x28\xE8\x40\x14\x0B\xD4\x09\x90\xE0\x1E\x03" # 1E = 96 MHz
fast_data = b"\x00\x0B\xCE\x08\xE8\x40\x14\x0B\xD4\x09\x90\xE0\x0E\x03"
smc  = patch(smc, CUT_START, slow_data + fast_data)

# pre-main init code
smc = patch (smc, INIT_START, init_bin + ljmp(0x2624))
smc = patch (smc, 0x770, lcall(INIT_START))

open("smc.bin", "wb").write(smc)
