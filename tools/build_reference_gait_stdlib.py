#!/usr/bin/env python3
"""Rebuild the 12 screenshot-derived body/boot layers with the Python stdlib.

No invented animation frames are added: this is the same alpha-only split as
build_reference_gait.py. Source PNGs must be 8-bit non-interlaced RGBA. Output
normally matches the checked-in optimized Pillow PNG bytes on zlib 1.3.1; if a
different zlib encodes the same pixels differently, the installer validates the
RGBA pixel hash instead of treating a harmless compression difference as an edit.

  python3 tools/build_reference_gait_stdlib.py --output-dir /tmp/gait-parts
  python3 tools/build_reference_gait_stdlib.py  # writes project asset directory
"""
from pathlib import Path
import argparse,struct,zlib

ROOT=Path(__file__).resolve().parents[1]
SIG=b'\x89PNG\r\n\x1a\n'

def paeth(a,b,c):
    p=a+b-c;pa=abs(p-a);pb=abs(p-b);pc=abs(p-c)
    return a if pa<=pb and pa<=pc else b if pb<=pc else c

def png_chunk(kind,data):
    return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data)&0xffffffff)

def read_rgba(path):
    data=path.read_bytes()
    if data[:8]!=SIG:raise ValueError(f'Not a PNG: {path}')
    pos=8;packed=[];header=None
    while pos+12<=len(data):
        n=struct.unpack('>I',data[pos:pos+4])[0];kind=data[pos+4:pos+8];chunk=data[pos+8:pos+8+n]
        crc=struct.unpack('>I',data[pos+8+n:pos+12+n])[0]
        if zlib.crc32(kind+chunk)&0xffffffff != crc:raise ValueError(f'PNG CRC mismatch: {path}')
        if kind==b'IHDR':header=chunk
        elif kind==b'IDAT':packed.append(chunk)
        elif kind==b'IEND':break
        pos+=12+n
    if header is None:raise ValueError(f'PNG header missing: {path}')
    w,h,bit,colour,comp,flt,interlace=struct.unpack('>IIBBBBB',header)
    if (bit,colour,comp,flt,interlace)!=(8,6,0,0,0):raise ValueError(f'Need non-interlaced RGBA8 PNG: {path}')
    decompressed=zlib.decompress(b''.join(packed));stride=w*4
    if len(decompressed)!=h*(stride+1):raise ValueError(f'Invalid scanline size: {path}')
    rows=[];prev=bytes(stride)
    for y in range(h):
        offset=y*(stride+1);ft=decompressed[offset];src=decompressed[offset+1:offset+1+stride];row=bytearray(stride)
        if ft>4:raise ValueError(f'Invalid PNG filter {ft}: {path}')
        for i,v in enumerate(src):
            a=row[i-4] if i>=4 else 0;b=prev[i];c=prev[i-4] if i>=4 else 0
            predict=(0,a,b,(a+b)//2,paeth(a,b,c))[ft]
            row[i]=(v+predict)&255
        rows.append(row);prev=row
    return header,w,h,rows

def filtered_row(raw,prev):
    n=len(raw);outs=[bytearray(n) for _ in range(5)];scores=[0]*5
    for i,v in enumerate(raw):
        a=raw[i-4] if i>=4 else 0;b=prev[i];c=prev[i-4] if i>=4 else 0
        estimates=(0,a,b,(a+b)//2,paeth(a,b,c))
        for j,pred in enumerate(estimates):
            x=(v-pred)&255;outs[j][i]=x;scores[j]+=min(x,256-x)
    best=min(range(5),key=scores.__getitem__)
    return bytes([best])+outs[best]

def write_rgba(header,w,rows,dest):
    previous=bytes(w*4);filtered=[]
    for row in rows:
        filtered.append(filtered_row(row,previous));previous=row
    compressor=zlib.compressobj(9,zlib.DEFLATED,15,9,zlib.Z_FILTERED)
    packed=compressor.compress(b''.join(filtered))+compressor.flush()
    dest.write_bytes(SIG+png_chunk(b'IHDR',header)+png_chunk(b'IDAT',packed)+png_chunk(b'IEND',b''))

def build(index,out,source_dir=None):
    source_dir = source_dir or ROOT/'assets/reference/characters'
    header,w,h,rows=read_rgba(source_dir/f'{index:02}.png')
    cut=round(w*.82);overlap=6
    body=[bytearray(row) for row in rows];boot=[bytearray(row) for row in rows]
    for row in body:
        for x in range(min(w,cut+overlap),w):row[x*4+3]=0
    for row in boot:
        for x in range(0,cut):row[x*4+3]=0
    write_rgba(header,w,body,out/f'{index:02}_body.png')
    write_rgba(header,w,boot,out/f'{index:02}_boot.png')

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--source-dir',type=Path,default=ROOT/'assets/reference/characters')
    p.add_argument('--output-dir',type=Path,default=ROOT/'assets/reference/characters/parts')
    a=p.parse_args()
    a.output_dir.mkdir(parents=True,exist_ok=True)
    for i in range(1,13):build(i,a.output_dir,a.source_dir)
    print('Rebuilt 12 reference character body and boot layers.')
if __name__=='__main__':main()
