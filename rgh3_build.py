import struct, secrets, sys, hmac, hashlib
import Crypto.Cipher.ARC4 as RC4

key_1BL = b"\xDD\x88\xAD\x0C\x9E\xD6\x69\xE7\xB5\x67\x94\xFB\x68\x56\x3E\xFA"

def encrypt_smc(data):
    rnd = secrets.token_bytes(4)
    data = rnd + data[4:-8] + data[0:4] + b"\x00"*4
    key = [0x42, 0x75, 0x4e, 0x79]
    res = bytearray()
    for i in range(len(data)):
        j = data[i] ^ (key[i&3] & 0xFF)
        mod = j * 0xFB
        res += struct.pack("B", j)
        key[(i+1)&3] += mod
        key[(i+2)&3] += mod >> 8
    return bytes(res)

def encrypt_cba(cba):
     rnd = secrets.token_bytes(16)
     key = hmac.new(key_1BL, rnd, hashlib.sha1).digest()[0:0x10]
     return (key, cba[0:0x10] + rnd + RC4.new(key).encrypt(cba[0x20:]))

def encrypt_cbb(cbb, cba_key, cpu_key=b"\x00"*16):
    rnd = secrets.token_bytes(16)
    key = hmac.new(cba_key, rnd + cpu_key, hashlib.sha1).digest()[0:0x10]
    return cbb[0:0x10] + rnd + RC4.new(key).encrypt(cbb[0x20:])

def insert(image, data, offset=None):
    if offset is None:
        offset = len(image)
    if offset > len(image):
        image += b"\x00" * (offset - len(image))
    return image[:offset] + data + image[offset + len(data):]

# SMC
smc = open("smc.bin", "rb").read()
smc_ptr = 0x1000

# BLs
cba_ptr = 0x8000
cba = open("..\\cba.bin", "rb").read()
cbx = open("..\\cbx.bin", "rb").read()
cbb = open("cbb.bin", "rb").read()
cd  = open("..\\cd.bin", "rb").read()

# make header
image = struct.pack(">HHLLL64s16xLLLLLLLL", 0xFF4F, 1888, 0, cba_ptr, 0x70000, b"RGH3",  0x4000, 0x70000, 0x20712, 0x4000, 0x10000, 0, len(smc), smc_ptr)

# add SMC
image = insert(image, encrypt_smc(smc), smc_ptr)

# add BLs
(key, cba_enc) = encrypt_cba(cba)
image = insert(image, cba_enc, cba_ptr)
image = insert(image, encrypt_cbb(cbx, key))
image = insert(image, cbb)
image = insert(image, cd)

#add XeLL
xell  = open("..\\xell.bin", "rb").read()
image = insert(image, xell, 0xC0000)
image = insert(image, xell, 0x100000)

# save image
open("image.bin", "wb").write(image)