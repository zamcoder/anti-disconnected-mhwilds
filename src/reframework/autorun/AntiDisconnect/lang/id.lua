-- Bahasa Indonesia. Same keys as the English texts in AntiDisconnect/lang.lua, and each text
-- takes the same values in the same order (%d, %s, ...); a text that does not is shown in
-- English. Game terms (lobby, quest, Link Party, Online Single Player, Idle) stay as the game
-- shows them in English; the rest follows the English words, in the casual kamu/aku tone
-- of Bulk Sell.

return {
    title = "Anti Disconnect",
    version = "Versi %s",
    language = "Language / Bahasa",

    afk_guard = "Cegah tendangan AFK (game memindahkanmu ke Online Single Player setelah 30 menit tanpa input)",
    afk_public_quests = "Juga saat quest dengan pemain di luar Link Party-ku",
    afk_welcome = "Kabari aku saat kembali setelah AFK guard menjagaku tetap online",
    afk_help = "Hanya tendangannya yang dicegah: setelah 3 menit tanpa input, pemain lain tetap melihatmu Idle, "
        .. "seperti di game biasa.",
    status_off = "AFK guard: mati.",
    status_starting = "AFK guard: menunggu game...",
    status_unavailable = "AFK guard: tidak tersedia di versi game ini (timer diam dari game tidak ditemukan).",
    status_not_needed = "AFK guard: tidak ada yang perlu dilakukan sekarang (kamu tidak sedang online bersama pemain lain).",
    status_lobby = "AFK guard: melindungimu di lobby.",
    status_link = "AFK guard: melindungimu di Link Party.",
    status_quest = "AFK guard: melindungimu di quest ini (hanya kamu dan Link Party-mu).",
    status_quest_all = "AFK guard: melindungimu di quest ini.",
    status_strangers = "AFK guard: tidak melindungimu di quest ini, karena ada pemain di luar Link Party-mu. "
        .. "Tendangan 30 menit dari game berlaku di sini.",
    status_unknown = "AFK guard: tidak melindungimu di quest ini (anggotanya tidak bisa dibaca).",
    idle_line = "Tanpa input selama %s · status Idle setelah %s · ditendang setelah %s",
    idle_held = "Tanpa input selama %s · timer game ditahan di %s, di bawah batas tendangan",
    limits_assumed = "(Batas dari game tidak bisa dibaca; dianggap 3:00 dan 30:00.)",

    steady_link = "Eksperimen: kirim sinyal \"aku masih di sini\" lebih sering di quest dan Link Party",
    steady_help = "Untuk koneksi tidak stabil seperti paket data: pemain lain lebih sering menerima kabar darimu, jadi "
        .. "jeda singkat lebih jarang membuatmu terputus. Memakai sedikit lebih banyak kuota. Matikan kalau ada yang terasa aneh.",
    link_line = "%s: %s · koneksi langsung %d dari %d · sinyal \"masih di sini\": %s",
    health_0 = "normal",
    health_1 = "lebih sering",
    health_nil = "tidak diketahui",
    report_button = "Salin laporan",
    report_done = "Laporan disalin: tempel di chat untuk mengirimnya. Juga disimpan di "
        .. "reframework/data/AntiDisconnect/report.txt. Isinya tanpa nama atau ID.",

    log_title = "Catatan disconnect",
    log_empty = "Belum ada yang tercatat.",
    log_more = "... %d catatan lebih lama ada di file",
    log_clear = "Hapus catatan",
    log_file = "Catatan lengkap: reframework/data/AntiDisconnect/events.json",
    log_hooks_missing = "Tidak dipantau di versi game ini: %s",
    log_repeat = " (x%d)",
    ev_start = "Anti Disconnect %s mulai",
    ev_session = "%s: %s -> %s",
    session_lobby = "Lobby",
    session_quest = "Sesi quest",
    session_link = "Link Party",
    session_memories = "Sesi memories",
    session_local = "Sesi lokal",
    ev_session_event = "%s: kabar engine %s",
    ev_about_you = " (tentang kamu)",
    ev_about_host = " (tentang host)",
    ev_leave_call = "%s: game-mu keluar dari sesi ini",
    ev_party_leave = "Link Party: game-mu keluar dari party (%s)",
    ev_lobby_leave = "Koneksi lobby berakhir: %s",
    ev_lobby_leave_clean = "Koneksi lobby berakhir (tanpa laporan error)",
    ev_health_failed = "%s: sinyal \"masih di sini\" yang lebih sering tidak bertahan (dikembalikan game)",
    ev_lobby_connect = "Koneksi lobby gagal: %s",
    ev_p2p = "%s: %s, koneksi langsung %d dari %d",
    ev_health = "%s: sinyal \"masih di sini\" %s -> %s",
    state_off = "tidak tersambung",
    state_solo = "online, sendirian",
    state_multi = "online bersama pemain lain",
    ev_context = "Jaringan: %s -> %s",
    ev_local_on = "Mode jaringan lokal nyala",
    ev_local_off = "Mode jaringan lokal mati",
    ev_login = "Status online-mu: %s -> %s",
    ev_app_error = "Error game %s (%d), area %s",
    ev_app_error_raw = "Error server %d, area %s",
    ev_app_error_engine = "Error game dari lapisan jaringan (%s), area %s",
    ev_engine_error = "Error jaringan: %s",
    ev_lobby_closed = "Koneksi lobby ditutup",
    ev_lobby_error = "Error koneksi lobby (kode %d)",
    ev_afk_saved = "AFK guard menjagamu tetap online (%d menit tanpa input)",
    ev_unknown = "Catatan tidak dikenal",

    toast_title = "Anti Disconnect",
    toast_welcome = "Selamat datang kembali! Kamu tanpa input selama %d menit. Anti Disconnect menjagamu tetap online "
        .. "(game menendang setelah %d menit).",
    toast_test_button = "Tampilkan pesan contoh",
    toast_test = "Begini cara Anti Disconnect memberi tahu sesuatu saat kamu main.",
    toast_test_hint = "Tutup menu REFramework (Insert) untuk melihatnya.",

    error = "Error: %s",
    ui_error = "Kesalahan UI: %s",
}
