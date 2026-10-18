# Anti Disconnect: panduan untuk pemain yang sering DC

Mod ini dibuat untuk kasus seperti ini: saat main bareng (Link Party, quest bareng, atau lobby) kamu tiba-tiba keluar party, padahal internetmu kelihatan normal dan teman-teman aman. Mod ini **mencatat penyebabnya** dan punya **eksperimen** untuk mengurangi DC.

Mod ini **tidak** mengirim apa pun ke server Capcom dan **tidak** mengubah save. Catatannya juga tidak menyimpan nama atau ID pemain.

## 1. Pasang

1. Pasang **REFramework** untuk Monster Hunter Wilds. Kalau kamu sudah pakai mod lain yang butuh REFramework, lewati langkah ini.
   - Unduh `MHWILDS.zip` dari https://github.com/praydog/REFramework-nightly/releases
   - Salin `dinput8.dll` dari zip itu ke folder game (di sebelah `MonsterHunterWilds.exe`).
2. Pasang mod **Anti Disconnect** dengan salah satu cara:
   - Impor zip-nya di Fluffy Mod Manager.
   - Atau salin folder `reframework` dari zip ke folder game.
3. Buka game, tekan **Insert**, lalu buka bagian **Anti Disconnect**. Pilih **Language / Bahasa → Bahasa Indonesia**.

## 2. Main seperti biasa

| Pengaturan | Bawaan | Untuk DC yang mana |
|---|---|---|
| "Eksperimen: kalau Steam putus sebentar, tunggu Steam tersambung lagi…" | **Nyala**, biarkan nyala | Kode **C1081-AAA-AAA2** atau **C1082-AAA-AAA2** (di catatan: `Context / LinkStateInactive` atau `LostAuth`). Ini DC yang paling sering terlihat sejauh ini. |
| "Eksperimen: kirim sinyal \"aku masih di sini\" lebih sering…" | Mati | Nyalakan hanya kalau catatanmu menunjukkan `PeerNorecvTimeout`, atau kalau aku minta. |

Yang pertama sudah dites: waktu hanya Steam yang diputus 8–9 detik, tanpa pengaturan ini game langsung Offline, dengan pengaturan ini game tetap online.

## 3. Setiap kali kena DC

1. **Screenshot** pesan error dan kodenya (tombol F12 di Steam).
2. Tekan **Insert** → **Anti Disconnect** → **Salin laporan**.
3. **Tempel** (Ctrl+V) di chat ke yang memberimu mod ini, lalu kirim bersama screenshot-nya.
4. Buka `C:\Program Files (x86)\Steam\logs\connection_log.txt` dengan Notepad, lalu cari (Ctrl+F) **tanggal dan menit** saat DC, misalnya `2026-10-18 13:59`. Salin baris-baris di sekitarnya dan kirim juga. Dari situ terlihat apakah Steam sendiri yang putus sesaat. Baris-baris itu memuat Steam ID-mu (`[U:1:…]`). Kalau kirim lewat chat pribadi tidak apa-apa; kalau ditempel di tempat umum, hapus dulu bagian itu.

Laporannya juga tersimpan di `reframework/data/AntiDisconnect/report.txt` di folder game.

## Tips untuk paket data HP

Ini bisa langsung dicoba dan sering membantu:
- Pakai **USB tethering** (kabel HP ke PC), bukan hotspot Wi‑Fi. Satu sambungan nirkabel jadi hilang.
- Kalau tetap hotspot: letakkan HP dekat PC, matikan **mode hemat baterai/daya** di HP, dan pakai pita **5 GHz** kalau HP-mu bisa.
- Hindari tempat dengan sinyal yang naik-turun, dan jangan biarkan HP mengunduh pembaruan saat main.

## Tips untuk Wi‑Fi di PC

Di log Steam pemain pertama, jaringan PC-nya putus sekitar 100 kali sejak Agustus, biasanya 6–7 detik setiap kali. Penyebab seperti ini ada di PC atau Wi‑Fi-nya sendiri:
- Pakai kabel LAN kalau bisa.
- Matikan hemat daya Wi‑Fi: **Device Manager → Network adapters → (adaptor Wi‑Fi) → Power Management**, lalu hapus centang *"Allow the computer to turn off this device to save power"*.
- Update driver Wi‑Fi, dan dekatkan PC ke router.
