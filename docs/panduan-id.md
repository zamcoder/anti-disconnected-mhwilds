# Panduan Anti Disconnect (Bahasa Indonesia)

## Apa yang dilakukan mod ini?

**1. AFK guard: mencegah ditendang karena diam.**

Contoh: kamu di Grand Hub bareng teman, lalu ditinggal makan.

| Waktu tanpa input | Tanpa mod | Dengan Anti Disconnect |
|---|---|---|
| 3 menit | Status kamu jadi **Idle** (terlihat teman) | Sama: tetap Idle |
| 30 menit | Ditendang ke Online Single Player, keluar dari lobby, quest, dan **Link Party** | **Tidak ditendang** |
| Kamu kembali | Harus cari lobby dan Link Party lagi | Muncul notif: *"Selamat datang kembali! Kamu tanpa input selama 34 menit. Anti Disconnect menjagamu tetap online."* |

Pengecualian: saat **quest bareng orang asing** (misalnya SOS), tendangan 30 menit tetap berlaku. Ini supaya adil, karena pemain yang AFK di quest orang lain dapat hadiah tanpa ikut berburu. Kalau mau, ini bisa dimatikan lewat centang *"Juga saat quest dengan pemain di luar Link Party-ku"*.

**2. Catatan disconnect.**

Setiap kali game melaporkan masalah jaringan, mod mencatat jam dan isinya. Contoh:

```
21:03:14  Error jaringan: WebSocketClient / Timeout
21:03:15  Koneksi lobby ditutup
21:03:15  Lobby: online bersama pemain lain -> tidak tersambung
21:03:16  Error game COMMON_BE_OFFLINE (106005), area CONTEXT
```

Cara membaca contoh di atas:
- Koneksi ke server lobby **timeout**: tidak ada balasan dari server, biasanya karena internet tersendat.
- Akibatnya kamu keluar dari lobby, lalu game memindahkanmu ke Offline Mode.

Catatan lengkap ada di `reframework/data/AntiDisconnect/events.json`.

## Yang **tidak** bisa dilakukan

Mod tidak bisa memperbaiki internet yang jelek, server yang memutus, atau koneksi teman. Untuk itu ikuti tips resmi Capcom: pakai kabel LAN, aktifkan UPnP, izinkan game di firewall, dan hindari VPN. Fitur sambung ulang otomatis menyusul di versi berikutnya.

## Menu

Buka menu REFramework (tombol **Insert**), lalu buka **Anti Disconnect**:

| Bagian | Isi |
|---|---|
| Language / Bahasa | English atau Bahasa Indonesia |
| Cegah tendangan AFK | Nyala/mati (bawaan: nyala) |
| Juga saat quest dengan pemain di luar Link Party-ku | Bawaan: mati |
| Kabari aku saat kembali | Notif "selamat datang kembali" (bawaan: nyala) |
| Baris status | Contoh: *AFK guard: melindungimu di lobby.* |
| Baris waktu | Contoh: *Tanpa input selama 12:34 · status Idle setelah 3:00 · ditendang setelah 30:00* |
| Catatan disconnect | 12 catatan terbaru + tombol **Hapus catatan** |

---

## Sesi tes pertama (±10 menit)

Lakukan **saat kamu main sendirian**, tidak sedang quest, dan tidak di Link Party. Di tes ini kamu memang akan ditendang ke Online Single Player satu kali, jadi jangan sedang bareng teman.

**Persiapan (aku yang jalankan saat kamu bilang "siap tes", dengan game masih tertutup):**
1. `tools\deploy.ps1 -Dev afk-test` memasang mod + panel tes.
2. Kamu buka game, lalu masuk **lobby online**. Private lobby sendirian juga boleh.

**Langkah tes** (buka menu Insert → **Anti Disconnect: AFK test (dev)**):

| # | Yang kamu lakukan | Yang harus terlihat |
|---|---|---|
| T1 | Diam 10 detik, lalu gerakkan mouse | `NoInputTimer` naik ±1 per detik, lalu kembali ke 0. `TO_NO_INPUT_TIME = 180`, `TO_NO_INPUT_DISCONNECT_TIME = 1800`, `isMultiplay_LOBBY = true` |
| T2 | Klik **T2**, tutup menu (Insert), **lepas tangan** ±10 detik | Status jadi Idle. Di panel: `LoginStatus = 3 AFK` |
| T3 | Di menu **Anti Disconnect**, **matikan** "Cegah tendangan AFK". Klik **T3/T4**, tutup menu, lepas tangan ±30 detik | Kamu **ditendang**: muncul pesan *Switched to Online Single Player due to inactivity*. Ini bukti mekanismenya benar. |
| T4 | Masuk lobby lagi. **Nyalakan** lagi "Cegah tendangan AFK". Klik **T3/T4**, tutup menu, lepas tangan ±90 detik, lalu gerakkan mouse | **Tidak** ditendang. `NoInputTimer` tertahan di 1740. Status AFK guard: *melindungimu di lobby*. Saat mouse bergerak, muncul notif "Selamat datang kembali… ±31 menit". Angkanya besar karena tombol tes memalsukan timer ke 1780 detik; itu normal. |
| P1 | Klik **P1** | Nama-nama yang dipakai mod ditulis ke log (aku yang baca) |

**Selesai:** tutup game, lalu aku jalankan `tools\deploy.ps1 -RemoveDev` (mod tetap terpasang, panel tes dilepas). Hasilnya aku baca sendiri dari `re2_framework_log.txt` dan `events.json`, jadi kamu tidak perlu menyalin log.

**Tes panjang (opsional, kapan saja):** biarkan game diam di lobby lebih dari 30 menit (misalnya saat makan). Saat kembali, harusnya muncul notif "Selamat datang kembali" dan kamu masih di lobby.
