import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Untuk fitur copy ke clipboard
import 'package:flutter_markdown/flutter_markdown.dart'; // Untuk render Markdown

import '../services/calendar_service.dart';
import '../services/schedule_parser.dart';

class ScheduleResultScreen extends StatefulWidget {
  final String scheduleResult; // Data hasil dari AI
  const ScheduleResultScreen({super.key, required this.scheduleResult});

  @override
  State<ScheduleResultScreen> createState() => _ScheduleResultScreenState();
}

class _ScheduleResultScreenState extends State<ScheduleResultScreen> {
  final CalendarService _calendarService = CalendarService();
  bool _isExporting = false;
  String? _calendarExportLink;

  Future<DateTime?> _pickDateTime(BuildContext context) async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );

    if (pickedDate == null || !context.mounted) return null;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
    );

    if (pickedTime == null) return null;

    return DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
  }

  Future<void> _exportToCalendar() async {
    final anchor = await _pickDateTime(context);
    if (!mounted) return;
    if (anchor == null) return;

    final events = ScheduleParser.parseMarkdownSchedule(
      widget.scheduleResult,
      anchor,
    );
    if (events.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Format jadwal belum berisi rentang waktu yang bisa diekspor.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isExporting = true);
    try {
      final link = _calendarService.buildParsedEventsSummaryLink(events);
      if (!mounted) return;
      setState(() => _calendarExportLink = link);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link Google Calendar berhasil dibuat.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export gagal: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      // APP BAR + COPY BUTTON
      appBar: AppBar(
        title: const Text("Hasil Jadwal Optimal"),
        actions: [
          IconButton(
            icon: _isExporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.calendar_month),
            tooltip: "Export ke Google Calendar",
            onPressed: _isExporting ? null : _exportToCalendar,
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: "Salin Jadwal",
            onPressed: () {
              // Menyalin seluruh hasil ke clipboard
              Clipboard.setData(ClipboardData(text: widget.scheduleResult));
              // Notifikasi kecil ke user
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Jadwal berhasil disalin!")),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // HEADER INFORMASI
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 15,
                ),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.indigo.shade100),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.auto_awesome, color: Colors.indigo),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Jadwal ini disusun otomatis oleh AI berdasarkan prioritas Anda.",
                        style: TextStyle(color: Colors.indigo, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              // AREA HASIL (MARKDOWN)
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha((0.05 * 255).round()),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  // Markdown otomatis memiliki scroll
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Markdown(
                      data: widget.scheduleResult, // Data dari AI
                      selectable: true, // Bisa copy sebagian teks
                      padding: const EdgeInsets.all(20),
                      // Styling agar tampilan lebih profesional
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(
                          fontSize: 15,
                          height: 1.6,
                          color: Colors.black87,
                        ),
                        // Styling heading
                        h1: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo,
                        ),
                        h2: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        h3: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.indigoAccent,
                        ),
                        // Styling tabel
                        tableBorder: TableBorder.all(
                          color: Colors.grey,
                          width: 1,
                        ),
                        tableHeadAlign: TextAlign.center,
                        tablePadding: const EdgeInsets.all(8),
                      ),
                      // Custom builder (opsional/advanced)
                      builders: {'table': TableBuilder()},
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              if (_calendarExportLink != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade100),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.link, color: Colors.green),
                          SizedBox(width: 8),
                          Text(
                            'Link Export Google Calendar',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        _calendarExportLink!,
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: _calendarExportLink!),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Link export berhasil disalin.'),
                              ),
                            );
                          },
                          icon: const Icon(Icons.copy),
                          label: const Text('Copy Link'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
              ],
              // TOMBOL KEMBALI
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.refresh),
                  label: const Text("Buat Jadwal Baru"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TableBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    dynamic element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    // Menggunakan render default (tidak diubah)
    return null;
  }
}
