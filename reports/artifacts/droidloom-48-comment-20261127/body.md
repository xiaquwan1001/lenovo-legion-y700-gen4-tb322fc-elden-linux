Third independent report — identical persisted state, on a network where all three AOSP probes answer `204` **today**, so the cell can sit permanently offline while the host is fully online. That separates your root cause 1 ("nothing ever re-checks") from "the host was behind the GFW", and it means `noInternetAccessExpected` alone would leave us with a cell that is enabled but has no working resolver.

Environment: Lenovo Legion Y700 Gen4 (`TB322FC`, SM8750), aarch64, Debian 13/trixie + phoc/phosh, campus Wi-Fi behind NAT. Captures in 1–4 were taken on `droidloom-{runtime,image,base} 0.1.0-49`; `0.1.0-51` is installed now and both code paths in 6 are unchanged in the 51 source.

1. Same disable state, reached the same way (`nsenter -t <android-init> -m -p -- dumpsys wifi`):
   `- DSBLE ID: 0 SSID: "Droidloom" ... NetworkSelectionStatus NETWORK_SELECTION_PERMANENTLY_DISABLED`
   `firstL2ConnectionAttempt=null, firstL3ConnectionAttempt=null`; every scan logs `Ignoring network selection disabled SSID: "Droidloom"`
   Per-network: `hasEverConnected: true / hasNeverDetectedCaptivePortal: true / hasEverValidatedInternetAccess: false`
   `/data/misc/apexdata/com.android.wifi/WifiConfigStore.xml`: `SelectionStatus=NETWORK_SELECTION_PERMANENTLY_DISABLED`, `DisableReason=NETWORK_SELECTION_DISABLED_NO_INTERNET_PERMANENT`, `CreatorUid=10072(systemui)`
   Downstream, all consistent: the netns `wlan0` is `UP,LOWER_UP` with no IPv4 and an empty `ip route` (zero L2 attempts, so zero DHCP), host `adb devices -l` is empty, `journalctl -u droidloomd -b` only has `ADB disconnect failed: no such device '10.177.0.2:5555'`.

2. At the same moment, from the host: `curl --noproxy '*' -o /dev/null -w '%{http_code}'` → `204` for `connectivitycheck.gstatic.com/generate_204`, `www.google.com/generate_204` and `wifi.vivo.com.cn/generate_204` (http and https). The disable is a memory of one bad session, not a live verdict — it has to be cleared explicitly, waiting does not help.

3. Your "secondary note" is a hard blocker on this network, not a 5 s timeout: UDP/53 is forwarded **only** to the university's resolver, so the `8.8.8.8` fallback never succeeds at all.
   Host, `busybox nslookup <name> <server>`: the campus resolver → resolves; `1.1.1.1`, `8.8.8.8`, `223.5.5.5`, `114.114.114.114` → `connection timed out`; TCP `8.8.8.8:853`, `223.5.5.5:853`, `223.5.5.5:443` → blocked. DoH-over-443 to a name works (`200`) but Android's system resolver does not use it.
   ⇒ Here re-enabling the SSID alone cannot work: the first post-enable lookup fails, validation fails, and the network drops back to `NO_INTERNET_PERMANENT`. I fixed DNS first, so I have no log of that re-disable firing (your `counter:2` / +79 s is the only measurement of it I know of).

4. What restored it, in the order that mattered (DNS first, then re-enable), all reversible, no rebuild:
   a) `cmd settings put global captive_portal_{http,https,fallback}_url http(s)://wifi.vivo.com.cn/generate_204`
      — note `connect.rom.miui.com/generate_204` answers **200** on this network and is classified as a captive portal, so it is not a safe value to document as a fallback.
   b) a **separate** nft table for DNS: `ip dl_dns_redirect`, prerouting `iifname dlh1001 ip saddr 10.177.0.2 udp dport 53 dnat to <campus-resolver>`
      — separate on purpose: anything added to `droidloom_u1001*` is deleted together with the cell.
   c) `cmd wifi connect-network "Droidloom" open`
   Result: cell `wlan0 10.177.0.2/30` plus default route, `dumpsys connectivity` → `Active default network: 100 ... IS_VALIDATED`, host `adb devices -l` → `10.177.0.2:5555  device ... device:droidloom`.

5. Persistence is where users actually get stuck: after a host reboot `nft list ruleset | grep -c dl_dns_redirect` = `0`, and `journalctl -b | grep -c droidloom` = `0` — `droidloom.service` is user-scope with `WantedBy=graphical-session.target`, and that target is inactive on this stack, so the cell is not even started. The `captive_portal_*` values do survive (they land in `/data/system/users/0/settings_global.xml`); the nft table does not. Net effect: (a)–(c) are re-done by hand after every reboot.
   One thing in that same post-reboot state I cannot explain and am **not** claiming is this bug: the cell did come up with `10.177.0.2/30` (so the persisted disable had not re-applied that time), yet with `dlh1001 10.177.0.1/30` and `wlan0 10.177.0.2/30` both up the host saw `ping 10.177.0.2` at 100% loss and adb had no endpoint. Worth knowing because "the cell got 10.177.0.2" is then not a sufficient acceptance check for a fix.

6. Both halves still ship in `0.1.0-51` (read from the release source tarball, not from a fork):
   `runtime/droidloom-supervisor/src/development_network.rs:33` — `const LEASE: Lease = Lease { ... dns: [Ipv4Addr::new(1,1,1,1), Ipv4Addr::new(8,8,8,8)] }` (comment above it: "public resolvers so the cell does not depend on the host's resolver")
   `android/framework/droidloom-systemui/src/com/android/systemui/wifi/WifiProvisioning.java:42` — `if (preferences.getBoolean(DONE, false)) return;` and `:82` — `wifi.enableNetwork(networkId, false)`
