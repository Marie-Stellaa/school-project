import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_langage.dart';
import 'create_task_screen.dart';
import 'session_screen.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});
  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final _user = FirebaseAuth.instance.currentUser;
  final _firestore = FirebaseFirestore.instance;
  String _filter = 'Tous';
  final List<String> _filters = ['Tous','En cours','Terminées','À faire'];
  AppLanguage get _lang => AppLanguage.instance;

  Stream<QuerySnapshot> _getTasksStream() {
    return _firestore.collection('users').doc(_user?.uid).collection('tasks')
        .orderBy('createdAt', descending: true).snapshots();
  }

  List<QueryDocumentSnapshot> _filterTasks(List<QueryDocumentSnapshot> tasks) {
    switch (_filter) {
      case 'En cours': return tasks.where((t) => t['status'] == 'active').toList();
      case 'Terminées': return tasks.where((t) => t['status'] == 'done').toList();
      case 'À faire': return tasks.where((t) => t['status'] == 'active' && (t['progress'] ?? 0.0) < 0.1).toList();
      default: return tasks;
    }
  }

  Future<void> _deleteTask(String taskId) async {
    await _firestore.collection('users').doc(_user?.uid).collection('tasks').doc(taskId).delete();
  }
  void _showTaskOptions(QueryDocumentSnapshot task) {
    final isDone = task['status'] == 'done';
    if (isDone) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(task['title'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.play_arrow_rounded, color: Colors.green),
              title: const Text('Continuer la session'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => SessionScreen(
                    taskTitle: task['title'] ?? '',
                    durationHours: (task['duration'] ?? 0.0).toDouble(),
                    blockedApps: List<String>.from(task['blockedApps'] ?? []),
                    taskId: task.id,
                  ),
                ));
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Supprimer', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteTask(task.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLanguage.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FC),
          body: SafeArea(
            child: Column(children: [
              Container(
                color: const Color(0xFF0A0F2C),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    GestureDetector(onTap: () => Navigator.pop(context),
                        child: Container(width: 34, height: 34,
                            decoration: BoxDecoration(color: Colors.white.withAlpha(20), shape: BoxShape.circle),
                            child: const Icon(Icons.arrow_back, color: Colors.white, size: 16))
                    ),
                    Text(_lang.tr('tasks'),
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                    GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateTaskScreen())),
                        child: Container(width: 34, height: 34,
                            decoration: BoxDecoration(color: Colors.white.withAlpha(20), shape: BoxShape.circle),
                            child: const Icon(Icons.add, color: Colors.white, size: 18)
                        )
                    ),
                  ]),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: _filters.map((f) => GestureDetector(
                      onTap: () => setState(() => _filter = f),
                      child: Container(margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                              color: _filter == f ? Colors.white : Colors.white.withAlpha(20),
                              borderRadius: BorderRadius.circular(20)
                          ),
                          child: Text(f, style: TextStyle(
                              color: _filter == f ? const Color(0xFF0A0F2C) : Colors.white,
                              fontSize: 12, fontWeight: FontWeight.w600)
                          )
                      ),
                    )).toList()
                    ),
                  ),
                ]),
              ),
              Expanded(child: StreamBuilder<QuerySnapshot>(
                stream: _getTasksStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFF0A0F2C)));
                  }
                  final allTasks = snapshot.data?.docs ?? [];
                  final tasks = _filterTasks(allTasks);
                  if (tasks.isEmpty) {
                    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.task_alt, size: 60, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text(_filter == 'Tous' ? _lang.tr('no_task_yet') : 'Aucune tâche dans cette catégorie',
                          style: const TextStyle(color: Colors.black45, fontSize: 14)),
                    ])
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      final isDone = task['status'] == 'done';
                      final progress = task['progress'] ?? 0.0;
                      return Dismissible(
                        key: Key(task.id),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) => _deleteTask(task.id),
                        background: Container(margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(16)),
                            alignment: Alignment.centerRight,
                            child: const Icon(Icons.delete, color: Colors.white)),
                        child: GestureDetector(
                          onTap: () => _showTaskOptions(task),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                              border: isDone ? Border.all(color: const Color(0xFF3B6D11).withAlpha(50)) : null),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Container(width: 36, height: 36,
                                  decoration: BoxDecoration(
                                      color: isDone ? const Color(0xFFEAF3DE) : const Color(0xFFEEF2FF),
                                      shape: BoxShape.circle),
                                  child: Icon(isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                                      color: isDone ? const Color(0xFF3B6D11) : const Color(0xFF0A0F2C), size: 20)),
                              const SizedBox(width: 12),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(task['title'], style: TextStyle(color: const Color(0xFF0A0F2C),
                                    fontSize: 14, fontWeight: FontWeight.w700,
                                    decoration: isDone ? TextDecoration.lineThrough : null)),
                                Text('${task['duration']}h · ${task['blockedApps']?.length ?? 0} apps bloquées',
                                    style: const TextStyle(color: Colors.black45, fontSize: 11)),
                              ])
                              ),
                              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                      color: isDone ? const Color(0xFFEAF3DE) : const Color(0xFFEEF2FF),
                                      borderRadius: BorderRadius.circular(8)),
                                  child: Text(isDone ? _lang.tr('completed') : 'En cours',
                                      style: TextStyle(color: isDone ? const Color(0xFF3B6D11) : const Color(0xFF0A0F2C),
                                          fontSize: 10, fontWeight: FontWeight.w700)
                                  )
                              ),
                            ]),
                            const SizedBox(height: 10),
                            ClipRRect(borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(value: progress,
                                    backgroundColor: Colors.grey.shade100,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        isDone ? const Color(0xFF3B6D11) : const Color(0xFF0A0F2C)),
                                    minHeight: 6)
                            ),
                            const SizedBox(height: 4),
                            Text('${(progress * 100).toInt()}% accompli',
                                style: const TextStyle(color: Colors.black38, fontSize: 10)),
                          ]),
                        ),

                        )
                      );
                    }
                  );
                },
              )
              ),
            ]),
          ),
        );
      },
    );
  }
}