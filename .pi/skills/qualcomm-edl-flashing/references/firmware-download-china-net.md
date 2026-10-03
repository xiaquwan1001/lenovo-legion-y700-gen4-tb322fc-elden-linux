# Firmware downloads on China-network hosts (lolinet & friends)

Context (TB321FU ROW 17.5.10.031, 6.99 GB zip, 2026-08-07): lolinet direct ≈ 33 KB/s or
times out entirely; the local HTTP proxy (127.0.0.1:7890, clash-style) works.

## Fast path: aria2 + local proxy, multi-connection
```bash
aria2c --all-proxy=http://127.0.0.1:7890 -x 16 -s 16 -k 1M \
  --max-tries=10 --retry-wait=5 --timeout=90 \
  -o dl/ROM.zip "<url>"
```
Measured: ~22 MB/s for the first 6+ GB (vs 300 KB/s single-connection curl through the
same proxy). Resuming: run the same command again — aria2 reads the `.aria2` control file.

## GitHub release assets on CN network: gh-proxy.com channel (2026-08-16, TB322FC GSI)
The local proxy can throttle badly on GitHub release assets (measured 300-500 KB/s for a
854 MB GSI xz). **`https://gh-proxy.com/https://github.com/<owner>/<repo>/releases/download/...`
sustained 3.8 MB/s (10x faster); `ghfast.top` was SLOWER (230 KB/s) — test before committing.**
- `curl -r 0-1048575 -o /dev/null -w "%{http_code} %{speed_download}"` a 1 MB range against
  each candidate to pick the fastest channel before starting the real download.
- Direct GitHub from CN often returns 000 (connection reset) — don't waste a retry on it.
- **Switching channels mid-download (aria2 resume)**: kill aria2, then re-run with the NEW
  URL and the SAME `-o <file>` — aria2 picks up the existing `.aria2` control file and
  resumes the already-downloaded pieces even though the URL changed. Verified: 218 MiB
  transferred to gh-proxy at ~14 MB/s effective, completing in ~2 min.

## Pitfalls
- **aria2 preallocates the file**: `ls -l` and `du -sb` report the FULL logical size even
  when only a few % have arrived. Gauge real progress with `du -sh` (disk usage).
- **aria2 can stall with holes**: 0-byte growth for minutes while the process stays alive,
  and the trailing zip central directory (EOCD `PK\x05\x06`) never appears → `unzip -l`
  fails with "End-of-central-directory signature not found". Kill and resume, or switch to
  targeted extraction (below). A file can be ~94 % holes while `du -sb` says "complete".
- Zip EOCD lives at the END of the file — partial downloads can't be listed, but their
  data is still extractable per-entry (see next section).

## Targeted extraction from a partially-downloaded zip (validated)
Firmware zips store big images uncompressed-ish; individual entries can be pulled from the
regions already downloaded, no full download needed:
1. Scan the file in 4 MB blocks; skip blocks that are all-zero (holes); within each block
   search for local headers `PK\x03\x04` (`b'\xd0\x0d\xfe\xed'` style search works).
2. At each hit, parse the local header: method @+8, csize @+18, usize @+22, filename
   length @+26, extra length @+28 (all little-endian u16/u32).
3. If the filename matches a target (`image/abl.elf`, `image/boot.img`, ...), seek to
   `off+30+fnlen+extralen`, read `csize` bytes, decompress with
   `zlib.decompress(data, -15)` (raw deflate, method=8; method=0 = stored, use as-is),
   and assert `len(out) == usize` before trusting it.
4. Result: extracted `image/abl.elf` (241 KB) and `image/boot.img` (96 MiB stock) from a
   zip that was ~94 % holes. Bonus: `contents.x` may be method=0 (stored, plaintext-ish
   catalog) — readable without any decryption.
5. If the target entry's local header still lies inside a hole: keep resuming aria2 until
   that region is covered, or use a smaller package (CN plain-XML packages are smaller).

## Verify before flashing
- `file repart/ROW_boot.img` → "Android bootimg" / `unpack_bootimg.py` for header fields.
- Compare against `fastboot getvar partition-size:boot_a` expectations; a stock boot.img is
  exactly the partition size (96 MiB here).
