import subprocess
import os
from tkinter.filedialog import * 
from tkinter.messagebox import *
from tibundle import TIBundle


dir = askdirectory(title = "Open folder with memlist.bin") 

# read memlist and get nonaudio related files
try: 
	memlist = open(f'{dir}\\memlist.bin','rb')
except:
	showerror(message="memlist.bin not found in directory.") 
	exit()

mementry = []
i = 0
while(1):
    barr = bytearray(memlist.read(20))
    if barr[0] == 255 :
        break
    if barr[1] == 0 or barr[1] == 1:
        i += 1
        continue

    mementry.append( \
        {'index':i, \
        'type':barr[1], \
        'bank':barr[7], \
        'offset':(int.from_bytes(barr[8:12], byteorder = 'big')), \
        'packedSize':(int.from_bytes(barr[14:16],byteorder = 'big')), \
        'size':(int.from_bytes(barr[18:20],byteorder = 'big')), } )
    i += 1

memlist.close()

def decompress(packedSize,buffer):
    readIndex = packedSize - 4

    def readWord():
        nonlocal readIndex
        nonlocal buffer
        word = int.from_bytes(buffer[readIndex:(readIndex+4)], byteorder = 'big')
        readIndex -= 4
        return word

    datasize = readWord()
    writeIndex = datasize - 1
    readWord() # dummy read to skip checksum word
    chunk = readWord()

    def writeByte(b):
        nonlocal writeIndex
        nonlocal buffer
        buffer[writeIndex] = b
        writeIndex -= 1

    def nextChunk():
        nonlocal chunk
        bit = chunk & 1
        chunk >>= 1
        if chunk == 0:
            chunk = readWord()
            bit = chunk & 1
            chunk >>= 1
            chunk |= 0x80000000
        return bit

    def getBits(num):
        nonlocal chunk
        result = 0
        for i in range(num):
            result <<= 1
            result |= nextChunk()
        return result

    def storeBytes(num):
        nonlocal datasize
        count = num + 1
        datasize -= count
        for i in range(count):
            writeByte(getBits(8))

    def storeFromOffset(offset):
        nonlocal datasize
        nonlocal buffer
        nonlocal writeIndex
        count = length + 1
        datasize -= count
        for i in range(count):
            n = buffer[writeIndex + offset]
            writeByte(n)

    while (datasize > 0):
        if (getBits(1) == 0):
            length = 1
            if (getBits(1) == 0):
                storeBytes(getBits(3))
            else:
                storeFromOffset(getBits(8))
        else:
            c = getBits(2)
            if c == 3:
                storeBytes(getBits(8) + 8)
            elif c < 2:
                length = c + 2
                storeFromOffset(getBits(c+9))
            else:
                length = getBits(8)
                storeFromOffset(getBits(12))



def interleavePlanes(buffer):
    # bitplanes of image
    plane0 = buffer[0:8000]
    plane1 = buffer[8000:16000]
    plane2 = buffer[16000:24000]
    plane3 = buffer[24000:32000]
    merged = bytearray()

    for i in range(0,8000):
        c0 = plane0[i]
        c1 = plane1[i]
        c2 = plane2[i]
        c3 = plane3[i]
        for j in range(0,4):
            color = 0
            #top nibble
            if c0 & 0x40:
                color |= 1<<4
            if c1 & 0x40:
                color |= 1<<5
            if c2 & 0x40:
                color |= 1<<6
            if c3 & 0x40:
                color |= 1<<7
            #bottom nibble
            if c0 & 0x80:
                color |= 1
            if c1 & 0x80:
                color |= 1<<1
            if c2 & 0x80:
                color |= 1<<2
            if c3 & 0x80:
                color |= 1<<3

            merged.append(color)

            c0 <<= 2
            c1 <<= 2
            c2 <<= 2
            c3 <<= 2
    return merged

#adjust palette to rgb555 format
def adjustPalettes(buffer):
    for i in range(0,2048,2):
        r = (buffer[i+1]&0x0F)<<1
        g = (buffer[i+1]&0xF0)>>3
        b = (buffer[i]&0x0F)<<1

        buffer[i] = ((g<<5)&0b11100000) + r
        buffer[i+1] = (b<<2) + (g>>3)
    return buffer

bundle = TIBundle("AWVARS.b84")

#iterate through list of entries and decompress and save to individual files
for entry in mementry:
    bank = entry['bank']
    size = entry['size']
    packedSize = entry['packedSize']
    index = entry['index']
    flags = ' '

    if size == 0:
        continue
    if (entry['type'] == 0 or entry['type'] == 1) :
        continue

    print(f'Fetching entry {index}...')

    bankfile = open(f'{dir}\\bank0{bank:x}','rb')

    bankfile.seek(entry['offset'])
    buffer = bytearray(bankfile.read(packedSize))
    bankfile.close()

    if (size != packedSize) :
        buffer.extend([0] * (size - packedSize))
        decompress(packedSize,buffer)

    if entry['type'] == 2:
        buffer = interleavePlanes(buffer)
    elif entry['type'] == 3:
        buffer = adjustPalettes(buffer)

    print(f'Size: {len(buffer)}')

    entryname = f'AW{index:X}'
    with open('temp.bin','wb') as f:
        f.write(buffer)

    if (entry['type'] == 2 or entry['type'] == 3):
        flags = '-c zx7'

    subprocess.run(f'convbin {flags} -j bin -i temp.bin -k 8xv -r -o temp.8xv -n {entryname}', shell = True)
    
    bundle.addFile('temp.8xv',f'{entryname}.8xv')



bundle.writeChecksum()
bundle.close()
os.remove(f"temp.bin")
os.remove(f"temp.8xv")
showinfo(message="Conversion successful!\nUnzip AWVARS.b84 for individual files.")
