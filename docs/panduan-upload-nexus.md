# Panduan rilis ke Nexus Mods

Panduan ini untuk maintainer. Alurnya sama dengan Bulk Sell: buat zip rilis, uji, lalu upload ke halaman Monster Hunter Wilds di Nexus Mods.

## 1. Siapkan versi

1. Naikkan `VERSION` di `src/reframework/autorun/AntiDisconnect.lua`, lalu tambah entri baru di `CHANGELOG.md`.
2. Jalankan test. Pastikan hasilnya `syntax errors: 0, failing test files: 0`:
   ```powershell
   .venv\Scripts\python.exe -I tools\check.py
   ```
3. Buat zip rilis:
   ```powershell
   powershell -ExecutionPolicy Bypass -File tools\package.ps1
   ```
   Hasilnya ada di `dist\AntiDisconnect-<versi>.zip`. Isinya `modinfo.ini` dan folder `reframework/autorun/...`. Panel tes dev tidak ikut masuk.

## 2. Screenshot untuk halaman Nexus

Ambil 2–3 screenshot dengan F12 Steam atau Win+Shift+S:
- menu **Anti Disconnect** (Insert), yang memperlihatkan status *protecting you in the lobby* dan catatan disconnect;
- notif **"Welcome back! …"** di kanan layar. Untuk memunculkannya: diam di lobby publik lebih dari 30 menit, atau minta aku pasang panel tes lalu pakai tombol T3/T4.

Pastikan tidak ada nama karakter atau info pribadi yang tidak ingin kamu tampilkan.

## 3. Upload ke Nexus Mods

Login di https://www.nexusmods.com, buka halaman game **Monster Hunter Wilds**, lalu pilih **Upload → Upload a mod**.

**Tab Mod details**

| Kolom | Isi |
|---|---|
| Name | `Anti Disconnect - AFK Guard and Connection Log` |
| Summary | `Stops the 30-minute AFK kick that also drops you out of your Link Party, logs why you disconnect, and tests a fix for players who keep dropping on mobile data or Wi-Fi. Beta: your disconnect reports help.` |
| Description | Tempel isi `docs/nexus-description.bbcode` |
| Category | **Utilities**. Kalau tidak ada, pilih yang paling dekat. |
| Version | `0.1.1` (sama dengan `VERSION`) |
| Language | English |
| Author | `evilryosaki` |
| Tags | Multiplayer, Online, Network, Quality of Life, REFramework, Utility |

**Tab Media:** upload screenshot dari langkah 2, lalu pilih satu sebagai gambar utama.

**Tab Files**

| Kolom | Isi |
|---|---|
| File | `dist\AntiDisconnect-0.1.1.zip` |
| File name | `Anti Disconnect` |
| Version | `0.1.1` |
| Category | **Main Files** |
| Description | `Beta. Fluffy Mod Manager ready. Requires REFramework.` |

**Tab Requirements:** tambahkan **REFramework** untuk Monster Hunter Wilds. Di *Off-site requirements* boleh juga ditambahkan link https://github.com/praydog/REFramework-nightly/releases

**Tab Permissions:** isi Credits sesuai README (REFramework oleh praydog, text dump oleh dtlnor). Repo memakai lisensi **MIT**, jadi sesuaikan izin di tab ini dengan lisensi itu.

**Publish:** cek pratinjau, lalu klik **Publish**.

## 4. Setelah publish

1. **Beri tahu aku link halaman Nexus-nya**, supaya aku tambahkan ke README dan formulir GitHub.
2. Tulis satu komentar yang di-*pin* (*Sticky*) di tab Posts:
   > **Got disconnected?** Press Insert → Anti Disconnect → Copy report, then post it with the [disconnect report form](https://github.com/zamcoder/anti-disconnected-mhwilds/issues/new?template=disconnect-report.yml) or in the Bugs tab. Please say if you were on cable, Wi-Fi or mobile data, and whether the steady link experiment was on.
3. Laporan yang masuk, baik dari GitHub maupun Nexus, tempel atau kirim link-nya ke aku. Nanti aku kelompokkan per penyebab dan jenis koneksi.

## 5. Merilis update

1. Ubah kode, naikkan `VERSION`, tambah entri di `CHANGELOG.md`, jalankan test, lalu jalankan `tools\package.ps1`.
2. Di Nexus, ubah **Version** di Mod details. Waktu Bulk Sell, langkah ini sempat terlewat, dan akibatnya pengecekan update jadi salah.
3. Di **Manage → Files**, upload zip baru sebagai **Main Files**, lalu pindahkan file lama ke **Old versions**.
4. Isi Changelog di Nexus dengan menyalin dari `CHANGELOG.md`.
5. Commit, beri tag versi, lalu push: `git tag v0.1.2` diikuti `git push origin main --tags`.

## 6. Checklist sebelum publish

- [ ] Test lolos (`tools\check.py`)
- [ ] `VERSION`, CHANGELOG, `modinfo.ini` (otomatis), dan Nexus memakai versi yang sama
- [ ] Zip sudah diuji: `tools\deploy.ps1 -Remove`, lalu import zip lewat Fluffy, lalu menu Anti Disconnect muncul dengan versi yang benar
- [ ] Panel tes dev sudah dilepas dari game
- [ ] Screenshot tidak menampilkan info pribadi
- [ ] Requirement REFramework sudah ditambahkan
