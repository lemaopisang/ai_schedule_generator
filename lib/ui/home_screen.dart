import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/calendar_service.dart';
import '../services/gemini_service.dart';
import 'schedule_result_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _prefsKey = 'ai_schedule_tasks';

  final GlobalKey<AnimatedListState> _listKey = GlobalKey();
  final CalendarService _calendarService = CalendarService();
  final List<Map<String, dynamic>> tasks = [];
  final TextEditingController taskController = TextEditingController();
  final TextEditingController durationController = TextEditingController();
  String? priority;
  bool isLoading = false;
  bool isSyncingCalendar = false;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  @override
  void dispose() {
    taskController.dispose();
    durationController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsKey);
    if (stored == null) return;
    final decoded = jsonDecode(stored) as List<dynamic>;
    final persisted = decoded
        .map((item) => Map<String, dynamic>.from(item as Map<String, dynamic>))
        .toList();
    setState(() => tasks.addAll(persisted));
  }

  Future<void> _persistTasks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(tasks));
  }

  void _addTask() {
    if (taskController.text.isEmpty || durationController.text.isEmpty || priority == null) {
      return;
    }

    final newTask = {
      "name": taskController.text,
      "priority": priority!,
      "duration": int.tryParse(durationController.text) ?? 30,
    };

    setState(() {
      tasks.insert(0, newTask);
      _listKey.currentState?.insertItem(0, duration: const Duration(milliseconds: 300));
    });

    _persistTasks();
    taskController.clear();
    durationController.clear();
    setState(() => priority = null);
  }

  void _removeTask(int index) {
    if (index < 0 || index >= tasks.length) return;
    final removed = tasks.removeAt(index);
    _listKey.currentState?.removeItem(
      index,
      (context, animation) => _buildTaskTile(removed, animation, index),
      duration: const Duration(milliseconds: 300),
    );
    _persistTasks();
  }

  Future<void> _syncToCalendar() async {
    if (tasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tambahkan tugas dulu sebelum sinkron ke Calendar.')),
      );
      return;
    }

    setState(() => isSyncingCalendar = true);
    try {
      await _calendarService.addTasksToCalendar(tasks);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tugas berhasil ditambahkan ke Google Calendar.')),
      );
    } catch (e) {
      if (mounted) {
        final message = e.toString().contains('clientId') ||
                e.toString().contains('sign_in_failed')
            ? 'Google Sign-In belum dikonfigurasi untuk platform ini.\nCek konfigurasi OAuth di Firebase/Google Cloud.'
            : 'Sinkron gagal: $e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => isSyncingCalendar = false);
    }
  }

  Future<void> _generateSchedule() async {
    if (tasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠ Harap tambahkan tugas dulu!")),
      );
      return;
    }
    setState(() => isLoading = true);
    try {
      String schedule = await GeminiService.generateSchedule(tasks);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ScheduleResultScreen(scheduleResult: schedule),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Color _getColor(String priority) {
    if (priority == "Tinggi") return Colors.red;
    if (priority == "Sedang") return Colors.orange;
    return Colors.green;
  }

  Widget _buildTaskTile(Map<String, dynamic> task, Animation<double> animation, int index) {
    return SizeTransition(
      sizeFactor: animation,
      axisAlignment: 0,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: _getColor(task['priority']),
            child: Text(
              task['name'][0].toUpperCase(),
              style: const TextStyle(color: Colors.white),
            ),
          ),
          title: Text(
            task['name'],
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text("${task['duration']} Menit • ${task['priority']}"),
          trailing: IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _removeTask(index),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("AI Schedule Generator"),
        actions: [
          IconButton(
            icon: isSyncingCalendar
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.calendar_month),
            tooltip: 'Sinkron ke Google Calendar',
            onPressed: isSyncingCalendar ? null : _syncToCalendar,
          ),
        ],
      ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: taskController,
                    decoration: const InputDecoration(
                      labelText: "Nama Tugas",
                      prefixIcon: Icon(Icons.task),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: durationController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: "Durasi (Menit)",
                            prefixIcon: Icon(Icons.timer),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: priority,
                          decoration: const InputDecoration(
                            labelText: "Prioritas",
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.flag),
                          ),
                          items: ["Tinggi", "Sedang", "Rendah"]
                              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                              .toList(),
                          onChanged: (val) => setState(() => priority = val),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 50,
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _addTask,
                      icon: const Icon(Icons.add),
                      label: const Text("Tambah ke Daftar"),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 50,
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: isSyncingCalendar ? null : _syncToCalendar,
                      icon: isSyncingCalendar
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.calendar_month),
                      label: Text(
                        isSyncingCalendar
                            ? 'Menyinkronkan ke Google Calendar...'
                            : 'Sign in & Sinkron ke Google Calendar',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: tasks.isEmpty
                ? const Center(
                    child: Text(
                      "Belum ada tugas.\nTambahkan tugas di atas!",
                      textAlign: TextAlign.center,
                    ),
                  )
                : AnimatedList(
                    key: _listKey,
                    initialItemCount: tasks.length,
                    itemBuilder: (context, index, animation) {
                      final task = tasks[index];
                      return Dismissible(
                        key: ValueKey('${task['name']}_${task['duration']}_${task['priority']}'),
                        background: Container(color: Colors.red),
                        onDismissed: (_) => _removeTask(index),
                        child: _buildTaskTile(task, animation, index),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: isLoading ? null : _generateSchedule,
        icon: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white),
              )
            : const Icon(Icons.auto_awesome),
        label: Text(isLoading ? "Memproses..." : "Buat Jadwal AI"),
      ),
    );
  }
}
