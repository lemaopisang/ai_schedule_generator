import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/calendar_service.dart';
import '../services/schedule_parser.dart';
import '../theme/app_theme.dart';

class ScheduleResultScreen extends StatefulWidget {
  final String scheduleResult;
  const ScheduleResultScreen({super.key, required this.scheduleResult});

  @override
  State<ScheduleResultScreen> createState() => _ScheduleResultScreenState();
}

class _ScheduleResultScreenState extends State<ScheduleResultScreen> {
  final CalendarService _calendarService = CalendarService();
  bool _isExporting = false;

  // ── DateTime picker ────────────────────────────────────────────────────────

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

  // ── Export to calendar ─────────────────────────────────────────────────────

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
              'Format jadwal belum berisi rentang waktu yang bisa diekspor.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isExporting = true);
    try {
      final link = _calendarService.buildParsedEventsSummaryLink(events);
      if (!mounted) return;
      _showCalendarLinkSheet(link);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export gagal: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // ── Calendar link bottom sheet ─────────────────────────────────────────────

  void _showCalendarLinkSheet(String link) {
    final cs = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
            24, 12, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.calendar_month_rounded,
                      color: Colors.green, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'Link Google Calendar',
                  style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: SelectableText(
                link,
                style: GoogleFonts.inter(fontSize: 11, height: 1.5),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                // Copy
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: link));
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Link berhasil disalin.'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Salin'),
                  ),
                ),
                const SizedBox(width: 12),
                // Open
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final uri = Uri.parse(link);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      }
                    },
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text('Buka'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Share ──────────────────────────────────────────────────────────────────

  void _shareSchedule() {
    Share.share(
      widget.scheduleResult,
      subject: 'Jadwal AI Schedule Generator',
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Gradient SliverAppBar ─────────────────────────────
          SliverAppBar(
            pinned: true,
            expandedHeight: 100,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.share_rounded, color: Colors.white),
                tooltip: 'Bagikan Jadwal',
                onPressed: _shareSchedule,
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, color: Colors.white),
                tooltip: 'Salin Semua',
                onPressed: () {
                  Clipboard.setData(
                      ClipboardData(text: widget.scheduleResult));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Jadwal berhasil disalin!')),
                  );
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding:
                  const EdgeInsets.only(left: 56, bottom: 14, right: 20),
              title: Text(
                'Hasil Jadwal',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              background: Container(
                decoration:
                    const BoxDecoration(gradient: AppTheme.brandGradient),
              ),
            ),
          ),

          // ── AI banner ─────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    cs.primaryContainer,
                    cs.primaryContainer.withAlpha(150),
                  ]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded,
                        color: cs.onPrimaryContainer, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Jadwal ini disusun otomatis oleh AI berdasarkan prioritas Anda.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: cs.onPrimaryContainer,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Markdown result ───────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1A2B3C)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: cs.shadow.withAlpha(20),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: MarkdownBody(
                    data: widget.scheduleResult,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet(
                      p: GoogleFonts.inter(
                        fontSize: 14,
                        height: 1.6,
                        color: cs.onSurface,
                      ),
                      h1: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: cs.primary,
                      ),
                      h2: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                      h3: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: cs.primary,
                      ),
                      strong: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                      blockquoteDecoration: BoxDecoration(
                        color: cs.primaryContainer.withAlpha(120),
                        border: Border(
                            left: BorderSide(
                                color: cs.primary, width: 3)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      tableBorder: TableBorder.all(
                        color: cs.outlineVariant,
                        width: 1,
                      ),
                      tableHeadAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Bottom actions ────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Row(
                children: [
                  // Export to Calendar
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isExporting ? null : _exportToCalendar,
                      icon: _isExporting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2),
                            )
                          : const Icon(Icons.calendar_month_rounded,
                              size: 16),
                      label: Text(
                          _isExporting ? 'Memproses...' : 'Google Calendar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Back
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Buat Baru'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
