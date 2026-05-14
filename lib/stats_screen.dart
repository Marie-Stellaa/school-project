import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_langage.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = AppLanguage.instance;
    final user = FirebaseAuth.instance.currentUser;
    final firestore = FirebaseFirestore.instance;

    return ListenableBuilder(
      listenable: AppLanguage.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFF4F6FB),
          body: SafeArea(
            child: StreamBuilder<QuerySnapshot>(
              stream: firestore.collection('users').doc(user?.uid).collection('tasks').snapshots(),
              builder: (context, snapshot) {
                final tasks = snapshot.data?.docs ?? [];
                final total = tasks.length;
                final done = tasks.where((t) => t['status'] == 'done').length;
                final active = tasks.where((t) => t['status'] == 'active').length;
                final totalHours = tasks.fold<double>(
                    0.0, (sum, t) => sum + ((t['duration'] ?? 0.0) as num).toDouble());
                final completionRate = total == 0 ? 0.0 : done / total;

                final now = DateTime.now();
                final weekDays = List.generate(7, (i) {
                  final day = now.subtract(Duration(days: now.weekday - 1 - i));
                  return DateTime(day.year, day.month, day.day);
                });
                final dayLabels = ['Lun','Mar','Mer','Jeu','Ven','Sam','Dim'];



                Map<int, int> tasksByDay = {};
                for (final task in tasks) {
                  final data = task.data() as Map<String, dynamic>;
                  if (data['status'] == 'done' && data['completedAt'] != null) {
                    final completedAt = data['completedAt'];
                    if (completedAt is Timestamp) {
                      final d = completedAt.toDate();
                      for (int i = 0; i < weekDays.length; i++) {
                        final wd = weekDays[i];
                        if (d.year == wd.year && d.month == wd.month && d.day == wd.day) {
                          tasksByDay[i] = (tasksByDay[i] ?? 0) + 1;
                        }
                      }
                    }
                  }
                }
                final maxTasks = tasksByDay.values.isEmpty ? 1
                    : tasksByDay.values.reduce((a, b) => a > b ? a : b);

                return Column(children: [
                  Container(
                    decoration: const BoxDecoration(color: Color(0xFF0A0F2C),
                        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28))),
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    child: Row(children: [
                      GestureDetector(onTap: () => Navigator.pop(context),
                          child: Container(width: 34, height: 34,
                              decoration: BoxDecoration(color: Colors.white.withAlpha(20), shape: BoxShape.circle),
                              child: const Icon(Icons.arrow_back, color: Colors.white, size: 16))),
                      const SizedBox(width: 12),
                      Text(lang.tr('my_stats'),
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                      if (snapshot.connectionState == ConnectionState.waiting)
                        const Padding(padding: EdgeInsets.only(left: 10),
                            child: SizedBox(width: 14, height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54))),
                    ]),
                  ),
                  Expanded(child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: const Color(0xFF0A0F2C), borderRadius: BorderRadius.circular(20)),
                        child: Row(children: [
                          SizedBox(width: 90, height: 90, child: Stack(alignment: Alignment.center, children: [
                            CircularProgressIndicator(value: completionRate, strokeWidth: 8,
                                backgroundColor: Colors.white.withAlpha(30),
                                valueColor: const AlwaysStoppedAnimation(Colors.white)),
                            Text('${(completionRate * 100).toInt()}%',
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                          ])),
                          const SizedBox(width: 20),
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(lang.tr('completion_rate'),
                                style: const TextStyle(color: Colors.white60, fontSize: 12)),
                            const SizedBox(height: 8),
                            Text('$done ${lang.tr("tasks_done")}',
                                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                            Text('sur $total au total',
                                style: const TextStyle(color: Colors.white54, fontSize: 12)),
                          ]),
                        ]),
                      ),
                      const SizedBox(height: 16),
                      GridView.count(
                        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.5,
                        children: [
                          _buildStatCard('✅', lang.tr('completed'), '$done', const Color(0xFFEAF3DE)),
                          _buildStatCard('📊', lang.tr('completion_rate'), '${(completionRate * 100).toInt()}%', const Color(0xFFEEF2FF)),
                          _buildStatCard('⏱️', 'Temps total', '${totalHours.toInt()}h', const Color(0xFFF4F6FB)),
                          _buildStatCard('⚡', 'En cours', '$active', const Color(0xFFFFF3CD)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Text(lang.tr('this_week'),
                                style: const TextStyle(color: Color(0xFF0A0F2C), fontSize: 15, fontWeight: FontWeight.w900)),
                            Text('$done ${lang.tr("tasks_done")}',
                                style: const TextStyle(color: Colors.black45, fontSize: 12)),
                          ]),
                          const SizedBox(height: 16),
                          ...List.generate(7, (i) {
                            final count = tasksByDay[i] ?? 0;
                            final ratio = maxTasks == 0 ? 0.0 : count / maxTasks;
                            return _buildDayBar(dayLabels[i], ratio, count);
                          }),
                        ]),
                      ),
                    ]),
                  )),
                ]);
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String emoji, String label, String value, Color bgColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Container(width: 36, height: 36, decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 18)))),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: const TextStyle(color: Color(0xFF0A0F2C), fontSize: 20, fontWeight: FontWeight.w900)),
          Text(label, style: const TextStyle(color: Colors.black45, fontSize: 11)),
        ]),
      ]),
    );
  }

  Widget _buildDayBar(String day, double value, int count) {
    final barColor = value >= 0.8 ? const Color(0xFF3B6D11)
        : value >= 0.4 ? const Color(0xFFBA7517)
        : value > 0 ? const Color(0xFF4FC3F7)
        : Colors.grey.shade200;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        SizedBox(width: 36, child: Text(day, style: const TextStyle(color: Colors.black45, fontSize: 12))),
        const SizedBox(width: 8),
        Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(value: value == 0 ? 0.02 : value,
                backgroundColor: Colors.grey.shade100,
                valueColor: AlwaysStoppedAnimation<Color>(barColor), minHeight: 10))),
        const SizedBox(width: 8),
        SizedBox(width: 28, child: Text('$count', textAlign: TextAlign.right,
            style: const TextStyle(color: Colors.black45, fontSize: 11))),
      ]),
    );
  }
}