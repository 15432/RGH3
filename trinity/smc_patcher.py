import struct

def patch(data, offset, new):
    return data[:offset] + new + data[offset + len(new):]

def lcall(offset):
    return b"\x12" + struct.pack(">H", offset)

def ljmp(offset):
    return b"\x02" + struct.pack(">H", offset)

INIT_START = 0x14BF
CODE_START = 0x2EE9

init_bin = open("init.bin", "rb").read()[INIT_START:]
msec_bin = open("msec.bin", "rb").read()
code_bin = open("code.bin", "rb").read()[CODE_START:]

smc = open("trinity_clean.bin", "rb").read()

# error processing patches
smc = patch(smc, 0x13A2, ljmp(0x13D8)) # go reboot on no_handshake

# GPIO patches
smc = patch(smc, 0x1308, b'\x80') # skip GPU check 1
smc = patch(smc, 0x1321, b'\x80') # skip GPU check 2
smc = patch(smc, 0x248A, b'\x00' * 3) # skip setting DBG as input
smc = patch(smc, 0x248F, b'\xc2') # skip reading dbg_led

# keep UART enabled
smc = patch(smc, 0x2502, b'\xC0') #  UART enable

# stack move patches
smc = patch(smc, 0x7E5, b'\xC3')
smc = patch(smc, 0x804, b'\xC3')

# main calls hijack
smc = patch(smc, CODE_START, code_bin)  # place main code

rom_end = 0x2FF8                        # there we'll place call stubs

for pos in range(0x857, 0x869, 3):      # shift methods
    smc = patch(smc, pos, smc[pos+3:pos+6])

smc = patch(smc, 0x869, lcall(CODE_START)) # call our func
smc = patch(smc, 0x87C, b"\xEC")           # include our func into internal cycle

# i2c re-arrange
CUT_START = 0x2bae
delay_func = b"\x7A\x09\xDA\xFE\x22"
smc = patch(smc, rom_end - len(delay_func), delay_func)
rom_end -= len(delay_func)

# delay refs
for off in [0x27F1, 0x27F7, 0x2839, 0x283E, 0x2BDD, 0x2BDD]:
    smc = patch(smc, off, lcall(rom_end))

#               IN  W   CE=[x8  E8  40  14] EX
slow_data = b"\x00\x0B\xCE\x28\xE8\x40\x14\x03"
fast_data = b"\x00\x0B\xCE\x08\xE8\x40\x14\x03"
smc  = patch(smc, CUT_START, slow_data + fast_data)

# pre-main init code
smc = patch (smc, INIT_START, init_bin + ljmp(0x2794) + msec_bin)
smc = patch (smc, 0x7FD, lcall(INIT_START))

open("smc.bin", "wb").write(smc)
