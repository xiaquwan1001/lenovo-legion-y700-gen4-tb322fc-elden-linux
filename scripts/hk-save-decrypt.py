#!/usr/bin/env python3
"""hk-save-decrypt.py — decrypt/encrypt Hollow Knight user*.dat saves.

Hollow Knight (PC/Android/macOS) stores each save as:

    <~25-byte binary header><base64(AES-256-ECB(plaintext))>

where the plaintext is the playerData JSON, PKCS#7 padded to the AES block
size. The AES key is a fixed string embedded in the game and is public:

    UKu52ePUBwetZ9wNX88o54dnfKRu0T1l        (32 ASCII chars = AES-256)

The same file format is used by the PC, Android and (unencrypted variant)
Switch ports, so a decrypted JSON can be re-encrypted for any of them.

usage:
    hk-save-decrypt.py decrypt <in.dat> [out.json]      # .dat -> plaintext JSON
    hk-save-decrypt.py encrypt <in.json> <out.dat>      # JSON -> .dat (needs --prefix)
    hk-save-decrypt.py info <in.dat>                    # show header/offsets only

For encrypt, the leading binary header of an existing save must be supplied
(--prefix-hex or --prefix-from <file>); those bytes appear to embed a
save-specific value, so always reuse the header of the file being replaced.
"""
import argparse
import base64
import binascii
import re
import sys

KEY = b"UKu52ePUBwetZ9wNX88o54dnfKRu0T1l"
B64_RE = re.compile(rb"[A-Za-z0-9+/]{64,}")
B64_CHARS = set(b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=")


def split_header(data: bytes):
    m = B64_RE.search(data)
    if not m:
        raise ValueError("no base64 payload found")
    start = m.start()
    end = m.end()
    while end < len(data) and data[end] in B64_CHARS:
        end += 1
    return data[:start], data[start:end], data[end:]


def aes_ecb(key: bytes, data: bytes, decrypt: bool) -> bytes:
    try:
        from Crypto.Cipher import AES  # pycryptodome
        cipher = AES.new(key, AES.MODE_ECB)
        return cipher.decrypt(data) if decrypt else cipher.encrypt(data)
    except ImportError:
        pass
    try:
        from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
        c = Cipher(algorithms.AES(key), modes.ECB()).decryptor() if decrypt else \
            Cipher(algorithms.AES(key), modes.ECB()).encryptor()
        return c.update(data) + c.finalize()
    except ImportError:
        raise SystemExit("need pycryptodome or cryptography (pip install pycryptodome)")


def unpad(b: bytes) -> bytes:
    n = b[-1]
    if 1 <= n <= 16 and b[-n:] == bytes([n]) * n:
        return b[:-n]
    return b


def pad(b: bytes) -> bytes:
    n = 16 - (len(b) % 16)
    return b + bytes([n]) * n


def cmd_decrypt(a):
    data = open(a.input, "rb").read()
    header, b64, suffix = split_header(data)
    ciphertext = base64.b64decode(b64)
    if len(ciphertext) % 16:
        raise SystemExit(f"ciphertext not block-aligned ({len(ciphertext)} bytes)")
    plain = unpad(aes_ecb(KEY, ciphertext, True))
    if not plain.lstrip().startswith(b"{"):
        print("WARNING: decrypted data does not start with '{'", file=sys.stderr)
    out = a.output or (a.input.rsplit(".", 1)[0] + ".json")
    open(out, "wb").write(plain)
    print(f"{a.input}: header={len(header)}B cipher={len(ciphertext)}B suffix={suffix!r} -> {out} ({len(plain)}B)")


def cmd_encrypt(a):
    plain = open(a.input, "rb").read()
    suffix = b""
    if a.prefix_hex:
        header = binascii.unhexlify(a.prefix_hex.replace(" ", ""))
    elif a.prefix_from:
        header, _, suffix = split_header(open(a.prefix_from, "rb").read())
    else:
        raise SystemExit("encrypt needs --prefix-hex or --prefix-from <existing .dat>")
    blob = base64.b64encode(aes_ecb(KEY, pad(plain), False))
    open(a.output, "wb").write(header + blob + suffix)
    print(f"{a.input}: header={len(header)}B suffix={suffix!r} -> {a.output} ({len(header)+len(blob)+len(suffix)}B)")


def cmd_info(a):
    data = open(a.input, "rb").read()
    header, b64, suffix = split_header(data)
    ct = base64.b64decode(b64)
    print(f"file       : {a.input} ({len(data)} bytes)")
    print(f"header     : {len(header)} bytes  hex={header.hex(' ')}")
    print(f"base64     : {len(b64)} chars  suffix={suffix!r}")
    print(f"ciphertext : {len(ct)} bytes  (mod16={len(ct)%16})")


def main():
    p = argparse.ArgumentParser()
    sub = p.add_subparsers(dest="cmd", required=True)
    d = sub.add_parser("decrypt"); d.add_argument("input"); d.add_argument("output", nargs="?"); d.set_defaults(f=cmd_decrypt)
    e = sub.add_parser("encrypt"); e.add_argument("input"); e.add_argument("output")
    e.add_argument("--prefix-hex"); e.add_argument("--prefix-from"); e.set_defaults(f=cmd_encrypt)
    i = sub.add_parser("info"); i.add_argument("input"); i.set_defaults(f=cmd_info)
    a = p.parse_args()
    a.f(a)


if __name__ == "__main__":
    main()
