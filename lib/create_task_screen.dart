import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_langage.dart';
import 'session_screen.dart';

class CreateTaskScreen extends StatefulWidget {
  final DateTime? selectedDate;
  const CreateTaskScreen({super.key, this.selectedDate});

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> with SingleTickerProviderStateMixin {
  final _titleCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  double _duration = 1.0;

  static const Map<String, String> _appPackages = {
    'TikTok':    'com.zhiliaoapp.musically',
    'Instagram': 'com.instagram.android',
    'YouTube':   'com.google.android.youtube',
    'Twitter':   'com.twitter.android',
    'Facebook':  'com.facebook.katana',
    'Snapchat':  'com.snapchat.android',
  };
  final List<String> _allApps = ['TikTok','Instagram','YouTube','Twitter','Facebook','Snapchat'];
  final List<String> _blockedApps = [];
  bool _strictMode = false;
  bool _calendarCollapsed = false;
  DateTime _selectedDate = DateTime.now();
  late DateTime _displayedMonth;
  final _firestore = FirebaseFirestore.instance;
  final _user = FirebaseAuth.instance.currentUser;
  late AnimationController _animCtrl;
  late Animation<double> _calendarAnim;
  AppLanguage get _lang => AppLanguage.instance;

  @override
  void initState() {
    super.initState();
    if (widget.selectedDate != null) _selectedDate = widget.selectedDate!;
    _displayedMonth = DateTime(_selectedDate.year, _selectedDate.month);
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _calendarAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut);
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.offset > 30 && !_calendarCollapsed) {
        setState(() => _calendarCollapsed = true);
        _animCtrl.forward();
      } else if (_scrollCtrl.offset <= 10 && _calendarCollapsed) {
        setState(() => _calendarCollapsed = false);
        _animCtrl.reverse();
      }
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _scrollCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  void _prevMonth() {
    setState(() {
      _displayedMonth = DateTime(
        _displayedMonth.month == 1 ? _displayedMonth.year - 1 : _displayedMonth.year,
        _displayedMonth.month == 1 ? 12 : _displayedMonth.month - 1,
      );
    });
  }

  void _nextMonth() {
    setState(() {
      _displayedMonth = DateTime(
        _displayedMonth.month == 12 ? _displayedMonth.year + 1 : _displayedMonth.year,
        _displayedMonth.month == 12 ? 1 : _displayedMonth.month + 1,
      );
    });
  }

  String _formatDuration(double hours) {
    if (hours < 1) return '${(hours * 60).toInt()}min';
    return '${hours.toStringAsFixed(hours == hours.toInt() ? 0 : 1)}h';
  }

  List<DateTime> _getDaysInMonth() {
    final last = DateTime(_displayedMonth.year, _displayedMonth.month + 1, 0);
    return List.generate(last.day, (i) => DateTime(_displayedMonth.year, _displayedMonth.month, i + 1));
  }

  Future<void> _startSession() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_lang.tr('task_title')??'Veuillez entrer un titre')),
      );
      return;
    }

    try {
      final docRef = await _firestore
          .collection('users')
          .doc(_user?.uid)
          .collection('tasks')
          .add({
        'title': _titleCtrl.text.trim(),
        'duration': _duration,
        'status': 'active',
        'progress': 0.0,
        'blockedApps': _blockedApps.map((name) => _appPackages[name] ?? name).toList(),
        'strictMode': _strictMode,
        'createdAt': FieldValue.serverTimestamp(),
        'date': _selectedDate.toIso8601String(),
      });

      if (!mounted) return;


      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => SessionScreen(
            taskTitle: _titleCtrl.text.trim(),
            durationHours: _duration,
            blockedApps: _blockedApps.map((name) => _appPackages[name] ?? name).toList(),
            taskId: docRef.id,
          ),
        ),
            (route) => route.isFirst,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    }
  }

  void _showYearPicker() {
    final currentYear = DateTime.now().year;
    final years = List.generate(10, (i) => currentYear - 2 + i);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
            color: Color(0xFF0A0F2C),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: Colors.white.withAlpha(40), borderRadius: BorderRadius.circular(4))),
          const Text('Choisir une année',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10, runSpacing: 10, alignment: WrapAlignment.center,
            children: years.map((year) {
              final isSelected = year == _displayedMonth.year;
              return GestureDetector(
                onTap: () {
                  setState(() => _displayedMonth = DateTime(year, _displayedMonth.month));
                  Navigator.pop(context);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                      color: isSelected ? Colors.white : Colors.white.withAlpha(15),
                      borderRadius: BorderRadius.circular(12)),
                  child: Text('$year', style: TextStyle(
                      color: isSelected ? const Color(0xFF0A0F2C) : Colors.white,
                      fontWeight: FontWeight.w700, fontSize: 14)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLanguage.instance,
      builder: (context, _) {
        final days = _getDaysInMonth();
        final firstWeekday = days.first.weekday % 7;
        final now = DateTime.now();

        return Scaffold(
          backgroundColor: const Color(0xFF0A0F2C),
          body: SafeArea(
            child: Column(children: [

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(children: [
                  Row(children: [
                    GestureDetector(onTap: () => Navigator.pop(context),
                        child: Container(width: 36, height: 36,
                            decoration: BoxDecoration(color: Colors.white.withAlpha(30), shape: BoxShape.circle),
                            child: const Icon(Icons.arrow_back, color: Colors.white, size: 18))),
                    const SizedBox(width: 12),
                    Text(_lang.tr('new_task'),
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                  ]),
                  const SizedBox(height: 14),
                  Container(
                    decoration: BoxDecoration(color: Colors.white.withAlpha(25), borderRadius: BorderRadius.circular(14)),
                    child: TextField(
                      controller: _titleCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: 'Ex: Monter une vidéo...',
                        hintStyle: const TextStyle(color: Colors.white38),
                        labelText: _lang.tr('task_title'),
                        labelStyle: const TextStyle(color: Colors.white54),
                        prefixIcon: const Icon(Icons.edit_outlined, color: Colors.white54, size: 20),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),


                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white.withAlpha(12),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white.withAlpha(20))),
                    child: Column(children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        GestureDetector(
                          onTap: _prevMonth,
                          child: Container(width: 32, height: 32,
                              decoration: BoxDecoration(color: Colors.white.withAlpha(15), shape: BoxShape.circle),
                              child: const Icon(Icons.chevron_left, color: Colors.white, size: 20)),
                        ),
                        GestureDetector(
                          onTap: _showYearPicker,
                          child: Row(children: [
                            Text('${_getMonthName(_displayedMonth.month)} ${_displayedMonth.year}',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                            const SizedBox(width: 4),
                            AnimatedRotation(
                              turns: _calendarCollapsed ? -0.25 : 0,
                              duration: const Duration(milliseconds: 300),
                              child: const Icon(Icons.keyboard_arrow_down, color: Colors.white54, size: 16),
                            ),
                          ]),
                        ),
                        GestureDetector(
                          onTap: _nextMonth,
                          child: Container(width: 32, height: 32,
                              decoration: BoxDecoration(color: Colors.white.withAlpha(15), shape: BoxShape.circle),
                              child: const Icon(Icons.chevron_right, color: Colors.white, size: 20)),
                        ),
                      ]),

                      SizeTransition(
                        sizeFactor: ReverseAnimation(_calendarAnim), axisAlignment: -1,
                        child: Column(children: [
                          const SizedBox(height: 10),
                          Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: ['D','L','M','M','J','V','S'].map((d) =>
                                  SizedBox(width: 28, child: Text(d, textAlign: TextAlign.center,
                                      style: const TextStyle(color: Colors.white38, fontSize: 10,
                                          fontWeight: FontWeight.w600)))).toList()),
                          const SizedBox(height: 6),
                          GridView.builder(
                            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 7, childAspectRatio: 1),
                            itemCount: days.length + firstWeekday,
                            itemBuilder: (context, index) {
                              if (index < firstWeekday) return const SizedBox();
                              final day = days[index - firstWeekday];
                              final isSelected = day.year == _selectedDate.year &&
                                  day.month == _selectedDate.month &&
                                  day.day == _selectedDate.day;
                              final isToday = day.year == now.year &&
                                  day.month == now.month &&
                                  day.day == now.day;
                              return GestureDetector(
                                onTap: () => setState(() => _selectedDate = day),
                                child: Container(
                                  margin: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                      color: isSelected ? Colors.white
                                          : isToday ? Colors.white.withAlpha(30)
                                          : Colors.transparent,
                                      shape: BoxShape.circle),
                                  child: Center(child: Text('${day.day}', style: TextStyle(
                                      color: isSelected ? const Color(0xFF0A0F2C) : Colors.white,
                                      fontSize: 11,
                                      fontWeight: isSelected || isToday ? FontWeight.w900 : FontWeight.normal))),
                                ),
                              );
                            },
                          ),
                        ]),
                      ),

                      if (_calendarCollapsed) ...[
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () { setState(() => _calendarCollapsed = false); _animCtrl.reverse(); },
                          child: Text(
                            '${_selectedDate.day} ${_getMonthName(_selectedDate.month)} ${_selectedDate.year}',
                            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ]),
                  ),
                ]),
              ),


              Expanded(child: Container(
                margin: const EdgeInsets.only(top: 14),
                decoration: const BoxDecoration(color: Color(0xFFF8F9FC),
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28))),
                child: SingleChildScrollView(
                  controller: _scrollCtrl, padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
                          border: const Border(left: BorderSide(color: Color(0xFF0A0F2C), width: 4))),
                      child: Row(children: [
                        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(10)),
                            child: Column(children: [
                              Text('${_selectedDate.day}',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0A0F2C))),
                              Text(_getMonthName(_selectedDate.month).substring(0, 3),
                                  style: const TextStyle(fontSize: 10, color: Colors.black45)),
                            ])),
                        const SizedBox(width: 12),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Date sélectionnée',
                              style: TextStyle(color: Color(0xFF0A0F2C), fontWeight: FontWeight.w700, fontSize: 13)),
                          Text('${_getMonthName(_selectedDate.month)} ${_selectedDate.year}',
                              style: const TextStyle(color: Colors.black45, fontSize: 11)),
                        ]),
                      ]),
                    ),
                    const SizedBox(height: 12),


                    Container(padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Text(_lang.tr('duration'),
                                style: const TextStyle(color: Color(0xFF0A0F2C), fontSize: 14, fontWeight: FontWeight.w900)),
                            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(color: const Color(0xFF0A0F2C), borderRadius: BorderRadius.circular(8)),
                                child: Text(_formatDuration(_duration),
                                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900))),
                          ]),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                                activeTrackColor: const Color(0xFF0A0F2C),
                                inactiveTrackColor: Colors.grey.shade200,
                                thumbColor: const Color(0xFF0A0F2C)),
                            child: Slider(value: _duration, min: 0.5, max: 8.0, divisions: 15,
                                onChanged: (v) => setState(() => _duration = v)),
                          ),
                          const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Text('30min', style: TextStyle(color: Colors.black45, fontSize: 11)),
                            Text('8h', style: TextStyle(color: Colors.black45, fontSize: 11)),
                          ]),
                        ])),
                    const SizedBox(height: 12),


                    Container(padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(_lang.tr('apps_to_block'),
                              style: const TextStyle(color: Color(0xFF0A0F2C), fontSize: 14, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 12),
                          Wrap(spacing: 8, runSpacing: 8, children: _allApps.map((app) {
                            final isSelected = _blockedApps.contains(app);
                            return GestureDetector(
                              onTap: () => setState(() => isSelected ? _blockedApps.remove(app) : _blockedApps.add(app)),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xFF0A0F2C) : const Color(0xFFF5F6FA),
                                    borderRadius: BorderRadius.circular(20)),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  Text(app, style: TextStyle(
                                      color: isSelected ? Colors.white : const Color(0xFF0A0F2C),
                                      fontSize: 12, fontWeight: FontWeight.w600)),
                                  const SizedBox(width: 4),
                                  Icon(isSelected ? Icons.close : Icons.add, size: 14,
                                      color: isSelected ? Colors.white : const Color(0xFF0A0F2C)),
                                ]),
                              ),
                            );
                          }).toList()),
                        ])),
                    const SizedBox(height: 12),


                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                      child: Row(children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(_lang.tr('strict_mode'),
                              style: const TextStyle(color: Color(0xFF0A0F2C), fontSize: 14, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 2),
                          Text(_lang.tr('strict_mode_sub'),
                              style: const TextStyle(color: Colors.black45, fontSize: 11)),
                        ])),
                        Switch(value: _strictMode, activeColor: const Color(0xFF0A0F2C),
                            onChanged: (v) => setState(() => _strictMode = v)),
                      ]),
                    ),
                    const SizedBox(height: 20),


                    SizedBox(width: double.infinity, child: ElevatedButton(
                      onPressed: _startSession,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0A0F2C),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      child: Text(_lang.tr('launch_session'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    )),
                  ]),
                ),
              )),
            ]),
          ),
        );
      },
    );
  }

  String _getMonthName(int month) {
    const months = ['Janvier','Février','Mars','Avril','Mai','Juin',
      'Juillet','Août','Septembre','Octobre','Novembre','Décembre'];
    return months[month - 1];
  }
}