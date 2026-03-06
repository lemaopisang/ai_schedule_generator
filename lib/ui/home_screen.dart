import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/gemini_service.dart';
import '../theme/app_theme.dart';
import 'schedule_result_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  static const _prefsKey = 'ai_schedule_tasks';
  static const _presetsKey = 'ai_schedule_presets';

  final GlobalKey<SliverAnimatedListState> _listKey = GlobalKey();
  final List<Map<String, dynamic>> tasks = [];
  Map<String, List<Map<String, dynamic>>> _presets = {};

  // Form controllers
  final TextEditingController _taskCtrl = TextEditingController();
  final TextEditingController _durationCtrl = TextEditingController();
  String? _priority;
  bool _isLoading = false;

  // FAB animation
  late final AnimationController _fabAnim;

  @override
  void initState() {
    super.initState();
    _fabAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _loadTasks();
    _loadPresets();
  }

  @override
  void dispose() {
    _taskCtrl.dispose();
    _durationCtrl.dispose();
    _fabAnim.dispose();
    super.dispose();
  }

  // â”€â”€ Persistence â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsKey);
    if (stored == null) return;
    final decoded = jsonDecode(stored) as List<dynamic>;
    final persisted = decoded
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    setState(() => tasks.addAll(persisted));
    if (tasks.isNotEmpty) _fabAnim.forward();
  }

  Future<void> _persistTasks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(tasks));
  }

  // ── Presets ────────────────────────────────────────────────────────────────

  Future<void> _loadPresets() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_presetsKey);
    if (raw == null) return;
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    setState(() {
      _presets = decoded.map((k, v) => MapEntry(
            k,
            (v as List<dynamic>)
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList(),
          ));
    });
  }

  Future<void> _persistPresets() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_presetsKey, jsonEncode(_presets));
  }

  Future<void> _savePreset(String name) async {
    if (tasks.isEmpty) return;
    setState(() => _presets[name] = List<Map<String, dynamic>>.from(tasks));
    await _persistPresets();
  }

  Future<void> _loadPreset(String name) async {
    final preset = _presets[name];
    if (preset == null) return;
    // Clear current list with animation
    for (var i = tasks.length - 1; i >= 0; i--) {
      final removed = tasks.removeAt(i);
      _listKey.currentState?.removeItem(
        i,
        (ctx, anim) =>
            _TaskCard(task: removed, animation: anim, onDelete: () {}),
        duration: const Duration(milliseconds: 150),
      );
    }
    await _persistTasks();
    await Future.delayed(const Duration(milliseconds: 200));
    // Insert preset tasks
    for (final task in preset) {
      tasks.add(task);
      _listKey.currentState?.insertItem(
        tasks.length - 1,
        duration: const Duration(milliseconds: 200),
      );
      await Future.delayed(const Duration(milliseconds: 60));
    }
    await _persistTasks();
    if (tasks.isNotEmpty) _fabAnim.forward();
  }

  Future<void> _deletePreset(String name) async {
    setState(() => _presets.remove(name));
    await _persistPresets();
  }

  // â”€â”€ Task management â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  void _addTask() {
    final name = _taskCtrl.text.trim();
    final dur = int.tryParse(_durationCtrl.text.trim()) ?? 0;
    if (name.isEmpty || dur <= 0 || _priority == null) {
      _showError('Isi semua field dengan benar.');
      return;
    }
    final newTask = {'name': name, 'priority': _priority!, 'duration': dur};
    setState(() {
      tasks.insert(0, newTask);
      _listKey.currentState?.insertItem(0,
          duration: const Duration(milliseconds: 300));
    });
    _persistTasks();
    _taskCtrl.clear();
    _durationCtrl.clear();
    setState(() => _priority = null);
    Navigator.of(context).pop(); // return to home
    _fabAnim.forward();
  }

  void _removeTask(int index) {
    if (index < 0 || index >= tasks.length) return;
    final removed = tasks.removeAt(index);
    _listKey.currentState?.removeItem(
      index,
      (ctx, anim) => _TaskCard(task: removed, animation: anim, onDelete: () {}), // ignore: avoid_types_as_parameter_names
      duration: const Duration(milliseconds: 300),
    );
    _persistTasks();
    if (tasks.isEmpty) _fabAnim.reverse();
  }

  // â”€â”€ Navigation â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _generateSchedule() async {
    if (tasks.isEmpty) {
      _showError('Harap tambahkan tugas dulu.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final schedule = await GeminiService.generateSchedule(tasks);
      if (!mounted) return;
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, anim, secondaryAnim) =>
              ScheduleResultScreen(scheduleResult: schedule),
          transitionsBuilder: (context, anim, secondaryAnim, child) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0.05, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
              child: child,
            ),
          ),
          transitionDuration: const Duration(milliseconds: 350),
        ),
      );
    } catch (e) {
      if (mounted) _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // â”€â”€ Helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  void _openAddTaskSheet() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, anim, secondaryAnim) => _AddTaskPage(
          taskCtrl: _taskCtrl,
          durationCtrl: _durationCtrl,
          priority: _priority,
          onPriorityChanged: (val) => setState(() => _priority = val),
          onAdd: _addTask,
        ),
        transitionsBuilder: (context, anim, secondaryAnim, child) =>
            SlideTransition(
          position: Tween(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  void _openPresetsPage() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, anim, secondaryAnim) => _PresetsPage(
          presets: _presets,
          currentTasks: tasks,
          onSave: (name) async {
            final messenger = ScaffoldMessenger.of(context);
            await _savePreset(name);
            messenger.showSnackBar(
              SnackBar(content: Text('Preset "$name" disimpan')),
            );
          },
          onLoad: (name) async {
            final messenger = ScaffoldMessenger.of(context);
            Navigator.of(context).pop();
            await _loadPreset(name);
            messenger.showSnackBar(
              SnackBar(content: Text('Preset "$name" dimuat')),
            );
          },
          onDelete: (name) async {
            final messenger = ScaffoldMessenger.of(context);
            await _deletePreset(name);
            messenger.showSnackBar(
              SnackBar(content: Text('Preset "$name" dihapus')),
            );
          },
        ),
        transitionsBuilder: (context, anim, secondaryAnim, child) =>
            SlideTransition(
          position: Tween(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  // â”€â”€ Build â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Stack(
      children: [
        AbsorbPointer(
          absorbing: _isLoading,
          child: Scaffold(
            body: CustomScrollView(
        slivers: [
          // â”€â”€ Gradient SliverAppBar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          SliverAppBar(
            expandedHeight: 140,
            floating: false,
            pinned: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.bookmark_border_rounded,
                    color: Colors.white),
                tooltip: 'Preset Tugas',
                onPressed: _openPresetsPage,
              ),
              const SizedBox(width: 4),
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding:
                  const EdgeInsets.only(left: 20, bottom: 14, right: 20),
              title: Text(
                'AI Schedule',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(gradient: AppTheme.brandGradient),
                child: SafeArea(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(30),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.white.withAlpha(60), width: 1),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.list_alt_rounded,
                                  color: Colors.white, size: 15),
                              const SizedBox(width: 6),
                              Text(
                                '${tasks.length} tugas',
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // â”€â”€ Hint banner â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      cs.primaryContainer,
                      cs.primaryContainer.withAlpha(160),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.tips_and_updates_rounded,
                        color: cs.onPrimaryContainer, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Tambah tugas lalu ketuk "Buat Jadwal AI" untuk memulai.',
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

          // â”€â”€ Task list â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          tasks.isEmpty
              ? SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(onAdd: _openAddTaskSheet),
                )
              : SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  sliver: SliverAnimatedList(
                    key: _listKey,
                    initialItemCount: tasks.length,
                    itemBuilder: (ctx, index, animation) {
                      final task = tasks[index];
                      return Dismissible(
                        key: ValueKey(
                            '${task['name']}_${task['duration']}_${task['priority']}_$index'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withAlpha(180),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.delete_rounded,
                              color: Colors.white),
                        ),
                        onDismissed: (_) => _removeTask(index),
                        child: _TaskCard(
                          task: task,
                          animation: animation,
                          onDelete: () => _removeTask(index),
                        ),
                      );
                    },
                  ),
                ),
        ],
      ),

      // â”€â”€ Add task button â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _BottomBar(
        isLoading: _isLoading,
        onAdd: _openAddTaskSheet,
        onGenerate: _generateSchedule,
      ),
    ),        // Scaffold
          ),  // AbsorbPointer

        // ── Full-screen loading overlay ────────────────────────────────────
        if (_isLoading) ...[
          const ModalBarrier(dismissible: false, color: Colors.black45),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 28),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(blurRadius: 32, color: Colors.black26),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    color: AppTheme.seed,
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Membuat jadwal...',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Mohon tunggu sebentar',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Add Task Bottom Sheet
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _AddTaskPage extends StatelessWidget {
  final TextEditingController taskCtrl;
  final TextEditingController durationCtrl;
  final String? priority;
  final ValueChanged<String?> onPriorityChanged;
  final VoidCallback onAdd;

  const _AddTaskPage({
    required this.taskCtrl,
    required this.durationCtrl,
    required this.priority,
    required this.onPriorityChanged,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Column(
        children: [
          // ── Gradient header ──────────────────────────────────────
          Container(
            decoration: const BoxDecoration(gradient: AppTheme.brandGradient),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 16, 20),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Tambah Tugas',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Form fields ──────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DETAIL TUGAS',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: cs.outline,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: taskCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Nama Tugas',
                      hintText: 'Contoh: Buat laporan mingguan',
                      prefixIcon: Icon(Icons.task_alt_rounded,
                          color: AppTheme.seed, size: 20),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: durationCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Durasi (menit)',
                            hintText: 'mis. 30',
                            prefixIcon: Icon(Icons.timer_rounded,
                                color: AppTheme.seed, size: 20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: priority,
                          decoration: InputDecoration(
                            labelText: 'Prioritas',
                            prefixIcon: Icon(Icons.flag_rounded,
                                color: AppTheme.seed, size: 20),
                          ),
                          items: [
                            _priorityItem('Tinggi', AppTheme.priorityHigh),
                            _priorityItem('Sedang', AppTheme.priorityMed),
                            _priorityItem('Rendah', AppTheme.priorityLow),
                          ],
                          onChanged: onPriorityChanged,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  _PriorityLegend(),
                ],
              ),
            ),
          ),

          // ── Add button ───────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(
                24, 12, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Tambah ke Daftar'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  DropdownMenuItem<String> _priorityItem(String label, Color color) {
    return DropdownMenuItem(
      value: label,
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}

class _PriorityLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = [
      (AppTheme.priorityHigh, 'Tinggi', 'Kerjakan secepatnya'),
      (AppTheme.priorityMed, 'Sedang', 'Penting, tapi tidak mendesak'),
      (AppTheme.priorityLow, 'Rendah', 'Bisa dikerjakan belakangan'),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Panduan Prioritas',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                        color: item.$1, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    item.$2,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: item.$1,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '— ${item.$3}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
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

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Task Card
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _TaskCard extends StatelessWidget {
  final Map<String, dynamic> task;
  final Animation<double> animation;
  final VoidCallback onDelete;

  const _TaskCard({
    required this.task,
    required this.animation,
    required this.onDelete,
  });

  Color _borderColor() {
    switch (task['priority']) {
      case 'Tinggi':
        return AppTheme.priorityHigh;
      case 'Sedang':
        return AppTheme.priorityMed;
      default:
        return AppTheme.priorityLow;
    }
  }

  Color _tagColor() => _borderColor();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SizeTransition(
      sizeFactor: animation,
      axisAlignment: 0,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border(
            left: BorderSide(color: _borderColor(), width: 4),
          ),
          boxShadow: [
            BoxShadow(
              color: cs.shadow.withAlpha(18),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            radius: 22,
            backgroundColor: _borderColor().withAlpha(30),
            child: Text(
              task['name'][0].toUpperCase(),
              style: GoogleFonts.poppins(
                color: _borderColor(),
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
          title: Text(
            task['name'],
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: const SizedBox.shrink(),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Duration chip
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${task['duration']}m',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: cs.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Priority badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _tagColor().withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  task['priority'],
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _tagColor(),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(Icons.delete_outline_rounded,
                    color: Colors.redAccent.withAlpha(180), size: 20),
                onPressed: onDelete,
                tooltip: 'Hapus',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Empty State
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.inbox_rounded, size: 72, color: cs.outlineVariant),
        const SizedBox(height: 16),
        Text(
          'Belum ada tugas',
          style: GoogleFonts.poppins(
              fontSize: 18, fontWeight: FontWeight.w600, color: cs.outline),
        ),
        const SizedBox(height: 8),
        Text(
          'Ketuk + untuk menambahkan\ntugas pertamamu.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
              fontSize: 13, color: cs.outlineVariant, height: 1.5),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Tambah Tugas'),
        ),
      ],
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Bottom Action Bar
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _BottomBar extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onAdd;
  final VoidCallback onGenerate;

  const _BottomBar({
    required this.isLoading,
    required this.onAdd,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Add button
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                    color: AppTheme.seed.withAlpha(180), width: 1.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: const Icon(Icons.add_rounded, color: AppTheme.seed),
                onPressed: onAdd,
                tooltip: 'Tambah Tugas',
              ),
            ),
            const SizedBox(width: 12),
            // Generate button
            Expanded(
              child: GestureDetector(
                onTap: isLoading ? null : onGenerate,
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: isLoading
                        ? LinearGradient(colors: [
                            AppTheme.seed.withAlpha(140),
                            AppTheme.seed.withAlpha(140),
                          ])
                        : AppTheme.brandGradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: isLoading
                        ? []
                        : [
                            BoxShadow(
                              color: AppTheme.seed.withAlpha(80),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isLoading)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      else
                        const Icon(Icons.auto_awesome_rounded,
                            color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        isLoading ? 'Memproses...' : 'Buat Jadwal AI',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Presets Page
// ────────────────────────────────────────────────────────────────────────────

class _PresetsPage extends StatefulWidget {
  final Map<String, List<Map<String, dynamic>>> presets;
  final List<Map<String, dynamic>> currentTasks;
  final Future<void> Function(String name) onSave;
  final Future<void> Function(String name) onLoad;
  final Future<void> Function(String name) onDelete;

  const _PresetsPage({
    required this.presets,
    required this.currentTasks,
    required this.onSave,
    required this.onLoad,
    required this.onDelete,
  });

  @override
  State<_PresetsPage> createState() => _PresetsPageState();
}

class _PresetsPageState extends State<_PresetsPage> {
  late Map<String, List<Map<String, dynamic>>> _local;

  @override
  void initState() {
    super.initState();
    _local = Map.from(widget.presets);
  }

  Future<void> _promptSave() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Simpan Preset',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Nama Preset',
            hintText: 'Contoh: Jadwal Senin',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await widget.onSave(name);
    setState(() {
      _local[name] = List<Map<String, dynamic>>.from(widget.currentTasks);
    });
  }

  Color _priorityColor(String p) {
    if (p == 'Tinggi') return AppTheme.priorityHigh;
    if (p == 'Sedang') return AppTheme.priorityMed;
    return AppTheme.priorityLow;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final names = _local.keys.toList();

    return Scaffold(
      body: Column(
        children: [
          // ── Gradient header ────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(gradient: AppTheme.brandGradient),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 16, 20),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Preset Tugas',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (widget.currentTasks.isNotEmpty)
                      TextButton.icon(
                        onPressed: _promptSave,
                        icon: const Icon(Icons.bookmark_add_rounded,
                            color: Colors.white, size: 18),
                        label: Text(
                          'Simpan',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white.withAlpha(30),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // ── Preset list ────────────────────────────────────────────
          Expanded(
            child: names.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bookmark_border_rounded,
                            size: 64, color: cs.outlineVariant),
                        const SizedBox(height: 16),
                        Text(
                          'Belum ada preset',
                          style: GoogleFonts.poppins(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: cs.outline),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tambahkan tugas lalu ketuk "Simpan"\nuntuk menyimpan preset.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              color: cs.outlineVariant,
                              height: 1.5),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: names.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) {
                      final name = names[i];
                      final taskList = _local[name]!;

                      return Container(
                        decoration: BoxDecoration(
                          color: cs.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border(
                            left: BorderSide(color: AppTheme.seed, width: 4),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: cs.shadow.withAlpha(18),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding:
                              const EdgeInsets.fromLTRB(16, 10, 8, 10),
                          title: Text(
                            name,
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: taskList.map((t) {
                                final c =
                                    _priorityColor(t['priority'] as String);
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: c.withAlpha(30),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    t['name'] as String,
                                    style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: c,
                                        fontWeight: FontWeight.w600),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Load
                              IconButton(
                                icon: Icon(Icons.download_rounded,
                                    color: AppTheme.seed, size: 22),
                                tooltip: 'Muat Preset',
                                onPressed: () => widget.onLoad(name),
                              ),
                              // Delete
                              IconButton(
                                icon: Icon(Icons.delete_outline_rounded,
                                    color: Colors.redAccent.withAlpha(180),
                                    size: 20),
                                tooltip: 'Hapus',
                                onPressed: () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (dctx) => AlertDialog(
                                      title: Text('Hapus Preset',
                                          style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.w700)),
                                      content: Text('Hapus preset "$name"?',
                                          style: GoogleFonts.inter()),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(dctx).pop(false),
                                          child: const Text('Batal'),
                                        ),
                                        FilledButton(
                                          style: FilledButton.styleFrom(
                                              backgroundColor: Colors.redAccent),
                                          onPressed: () =>
                                              Navigator.of(dctx).pop(true),
                                          child: const Text('Hapus'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirmed == true) {
                                    await widget.onDelete(name);
                                    setState(() => _local.remove(name));
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
