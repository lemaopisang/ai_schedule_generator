# AI Schedule Generator

Aplikasi Flutter untuk membuat jadwal harian dari daftar tugas menggunakan Gemini API.

## Setup

1. Salin file `.env.example` jadi `.env`, isi key kamu, dan pastikan `.env` tetap di-ignore (tidak di-commit):

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
- Simpan key di secret manager (CI/CD secret, backend proxy, dll) saat build/release. CI di repo ini sudah menggunakan secret `AI_API_KEY` untuk menjalankan `flutter build`.

## CI/CD (GitHub Actions)

- Workflow `/.github/workflows/flutter-ci.yml` berjalan pada push/pull request ke `main`.
- Ia menggunakan cache untuk `~/.pub-cache` dan `.dart_tool`, lalu menjalankan `flutter pub get`, `flutter analyze`, dan `flutter test`.
- Setelah lulus check, workflow membangun `flutter build apk --release` dan `flutter build web` dengan `--dart-define=GEMINI_API_KEY=${{ secrets.AI_API_KEY }}`.
- Kedua hasil build diunggah sebagai artifact: `release-apk` dan `web-release`.
- Tambahkan secret `AI_API_KEY` di GitHub repo settings agar CI bisa menyuntikkan key tanpa menaruhnya di repo.

## Legal

- [Privacy Policy](PRIVACY_POLICY.md)
- [Terms of Service](TERMS_OF_SERVICE.md)
