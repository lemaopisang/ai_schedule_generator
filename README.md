# AI Schedule Generator

Aplikasi Flutter untuk membuat jadwal harian dari daftar tugas menggunakan Gemini API.

## Setup

1. Buat/isi file `.env` di root project:

	`GEMINI_API_KEY=YOUR_GEMINI_API_KEY`

2. Jalankan dependency:

	`flutter pub get`

3. Jalankan aplikasi:

	`flutter run`

## Fitur Utama

- Tambah/hapus tugas dengan durasi dan prioritas.
- Generate jadwal AI dalam format Markdown.
- Copy hasil jadwal ke clipboard.
- Export ke Google Calendar via link (bukan OAuth/API Calendar).

## Export Google Calendar (Link)

- Dari halaman hasil jadwal, tekan ikon kalender.
- Pilih tanggal & jam anchor.
- Aplikasi membuat satu link Google Calendar berisi event ringkasan jadwal.
- Link muncul di halaman hasil dan bisa di-copy.

## Catatan Keamanan

- Jangan commit `.env` ke repository.
- API key di client app tetap bisa terekspos pada build production; untuk production, gunakan backend proxy.

## Legal

- [Privacy Policy](PRIVACY_POLICY.md)
- [Terms of Service](TERMS_OF_SERVICE.md)
