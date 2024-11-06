import struct

def patch(data, offset, new):
    return data[:offset] + new + data[offset + len(new):]

def lcall(offset):
    return b"\x12" + struct.pack(">H", offset)

def ljmp(offset):
    return b"\x02" + struct.pack(">H", offset)

INIT_START = 0x14C0
CODE_START = 0x31E0

init_bin = open("init.bin", "rb").read()[INIT_START:]
code_bin = open("code.bin", "rb").read()[CODE_START:]

smc = open("corona_clean.bin", "rb").read()

# error processing patches
smc = patch(smc, 0x13A3, ljmp(0x13D9)) # go reboot on no_handshake

# GPIO patches
smc = patch(smc, 0x256B, b'\x90') # P0.5 OUT dir
smc = patch(smc, 0x2539, b'\xC2') # force EXT_JTM to 0

# keep UART enabled
smc = patch(smc, 0x25B7, b'\xC0')

# stack move patches
smc = patch(smc, 0x7E5, b'\xC2') # own bytes BF..C2 at init
smc = patch(smc, 0x804, b'\xC2') # own bytes BF..C2 at main

# main calls hijack
smc = patch(smc, CODE_START, code_bin)  # place main code

rom_end = 0x37F0                        # there we'll place call stubs

for pos in range(0x805, 0x84d, 3):
    if pos == 0x829:                    # remove dbg LED FSM
        smc = patch(smc, pos, b"\x00" * 3)
        continue
    orig_addr = struct.unpack(">H", smc[pos+1:pos+3])[0]
    my_call = lcall(CODE_START) + ljmp(orig_addr)
    rom_end -= len(my_call)
    smc = patch(smc, rom_end, my_call)
    smc = patch(smc, pos, lcall(rom_end))

# i2c re-arrange
smc = patch(smc, rom_end - 0x10, smc[0x2e49:0x2e59])
rom_end -= 0x10
smc = patch(smc, 0x2E9A, lcall(rom_end))
smc = patch(smc, 0x2EA0, lcall(rom_end + 0xA))

#               IN  W   DB=[01  F0  01  Fx] EX
slow_data = b"\x00\x0E\xDB\x01\xF0\x01\xF0\x03"
fast_data = b"\x00\x0E\xDB\x01\xF0\x01\xF8\x03"
smc  = patch(smc, 0x2e49, slow_data + fast_data)

# pre-main init code
smc = patch (smc, INIT_START, init_bin + ljmp(0x293C))
smc = patch (smc, 0x7FD, lcall(INIT_START))

open("smc.bin", "wb").write(smc)
