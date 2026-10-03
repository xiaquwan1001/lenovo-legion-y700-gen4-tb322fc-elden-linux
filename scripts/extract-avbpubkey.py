#!/usr/bin/env python3
"""extract-avbpubkey.py — 从 AVB 镜像提取顶层公钥 blob（.avbpubkey 格式），
供 avbtool make_vbmeta_image --chain_partition 使用。
支持：裸 vbmeta（make_vbmeta_image 产物）、hash-footer 镜像（boot/recovery，
AVB0 block 在文件中部，由尾部 footer 描述）——自动搜 AVB0 magic。
用法：python3 extract-avbpubkey.py <image> <out.avbpubkey>
"""
import hashlib, struct, sys

def main(img_path, out_path):
    with open(img_path, 'rb') as f:
        data = f.read()
    i = data.find(b'AVB0')
    if i < 0:
        raise SystemExit(f'{img_path}: 无 AVB0 magic')
    h = data[i:i + 256]
    # AVB header 全部字段 big-endian:
    # magic(4) ver_major(4) ver_minor(4) auth_block(8) aux_block(8) alg(4)
    # hash_off(8) hash_sz(8) sig_off(8) sig_sz(8) pubkey_off(8) pubkey_sz(8) ...
    auth_block = struct.unpack_from('>Q', h, 12)[0]
    pub_off, pub_len = struct.unpack_from('>QQ', h, 64)
    # 公钥 blob 位于 AVB0 block 起点 + 256(header) + auth_block(hash+sig) + pub_off
    blob_start = i + 256 + auth_block + pub_off
    blob = data[blob_start:blob_start + pub_len]
    if len(blob) != pub_len or pub_len == 0:
        raise SystemExit(f'{img_path}: 公钥长度异常 pub_off={pub_off} pub_len={pub_len}')
    with open(out_path, 'wb') as f:
        f.write(blob)
    print(f'{img_path}: public key {pub_len}B sha1={hashlib.sha1(blob).hexdigest()} -> {out_path}')

if __name__ == '__main__':
    if len(sys.argv) != 3:
        raise SystemExit('usage: extract-avbpubkey.py <image> <out.avbpubkey>')
    main(sys.argv[1], sys.argv[2])
