import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_langage.dart';
import 'create_task_screen.dart';
import 'stats_screen.dart';
import 'task_list_screen.dart';
import 'profile_screen.dart';
import 'session_screen.dart';
import 'proof_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final _user = FirebaseAuth.instance.currentUser;
  final _firestore = FirebaseFirestore.instance;
  String _pseudo = '';
  int _streak = 0;
  String _profileImageUrl = '';
  bool _hasShownAccessibilityDialog = false;

  // Cache pour le streak
  int _cachedStreak = 0;
  DateTime _lastStreakUpdate = DateTime(2000);

  static const _channel = MethodChannel('com.Phanie.focus_launch/blocker');

  // Écrans pour la navigation
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _initializeScreens();
    _loadPseudo();
    _loadStreak();
    _loadProfileImage();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAccessibilityPermission();
    });
  }

  void _initializeScreens() {
    _screens = [
      HomeContent(
        streak: _streak,
        profileImageUrl: _profileImageUrl,
        onRefreshNeeded: _refreshEverything,
      ),
      const TaskListScreen(),
      const StatsScreen(),
      const ProfileScreen(),
    ];
  }

  Future<void> _loadPseudo() async {
    if (_user == null) return;
    try {
      final doc = await _firestore.collection('users').doc(_user!.uid).get();
      if (doc.exists && mounted) {
        setState(() {
          _pseudo = doc.data()?['pseudo'] ??
              _user!.email?.split('@').first ??
              'Utilisateur';
        });
      }
    } catch (e) {
      debugPrint('Erreur chargement pseudo: $e');
      if (mounted) {
        setState(() {
          _pseudo = _user?.email?.split('@').first ?? 'Utilisateur';
        });
      }
    }
  }

  Future<void> _loadProfileImage() async {
    if (_user == null) return;
    try {
      final doc = await _firestore.collection('users').doc(_user!.uid).get();
      if (doc.exists && mounted) {
        setState(() {
          _profileImageUrl = doc.data()?['profileImageUrl'] ?? '';
        });
      }
    } catch (e) {
      debugPrint('Erreur chargement photo: $e');
    }
  }

  Future<void> _refreshEverything() async {
    await Future.wait([
      _loadPseudo(),
      _loadStreak(),
      _loadProfileImage(),
    ]);
    // Mettre à jour l'écran HomeContent avec les nouvelles valeurs
    if (mounted) {
      setState(() {
        _screens[0] = HomeContent(
          streak: _streak,
          profileImageUrl: _profileImageUrl,
          onRefreshNeeded: _refreshEverything,
        );
      });
    }
  }

  Future<void> _loadStreak() async {
    // Vérifier si le cache est encore valide (moins de 5 minutes)
    if (DateTime.now().difference(_lastStreakUpdate).inMinutes < 5 && _cachedStreak > 0) {
      if (mounted) setState(() => _streak = _cachedStreak);
      return;
    }

    final streak = await _computeStreak();
    if (mounted) {
      setState(() {
        _streak = streak;
        _cachedStreak = streak;
        _lastStreakUpdate = DateTime.now();
      });
    }
  }

  Future<int> _computeStreak() async {
    if (_user == null) return 0;

    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Optimisation : Récupérer seulement les 30 derniers jours avec limite
      final cutoff = Timestamp.fromDate(today.subtract(const Duration(days: 30)));

      final snap = await _firestore
          .collection('users')
          .doc(_user!.uid)
          .collection('tasks')
          .where('status', isEqualTo: 'done')
          .where('completedAt', isGreaterThanOrEqualTo: cutoff)
          .limit(100)
          .get();

      final completedDays = <DateTime>{};
      for (final doc in snap.docs) {
        final ts = doc['completedAt'];
        if (ts is Timestamp) {
          final d = ts.toDate();
          completedDays.add(DateTime(d.year, d.month, d.day));
        }
      }

      int streak = 0;
      for (int i = 0; i < 365; i++) {
        final day = DateTime(now.year, now.month, now.day - i);
        if (!completedDays.contains(day)) break;
        streak++;
      }
      return streak;
    } catch (e) {
      debugPrint('Erreur calcul streak: $e');
      return _cachedStreak;
    }
  }

  Future<void> _checkAccessibilityPermission() async {
    if (_hasShownAccessibilityDialog) return;

    try {
      final bool isEnabled = await _channel.invokeMethod('isAccessibilityEnabled') ?? false;
      if (!isEnabled && mounted) {
        _hasShownAccessibilityDialog = true;
        _showAccessibilityDialog();
      }
    } catch (e) {
      debugPrint('Erreur vérification accessibilité: $e');
    }
  }

  void _showAccessibilityDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('🔒 Activer le blocage',
            style: TextStyle(
                color: Color(0xFF0A0F2C),
                fontWeight: FontWeight.w900,
                fontSize: 16)),
        content: const Text(
          'Pour bloquer les apps distrayantes, active Focus Launch dans les paramètres d\'accessibilité.\n\nParamètres → Accessibilité → Focus Launch Blocker → Activer',
          style: TextStyle(color: Colors.black54, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Plus tard', style: TextStyle(color: Colors.black45)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _channel.invokeMethod('openAccessibilitySettings');
              } catch (e) {
                debugPrint('Erreur ouverture settings: $e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0A0F2C),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Activer maintenant',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF0A0F2C),
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Accueil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.task_outlined),
            activeIcon: Icon(Icons.task),
            label: 'Tâches',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            activeIcon: Icon(Icons.bar_chart),
            label: 'Stats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF0A0F2C),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateTaskScreen()),
          );
          await _refreshEverything();
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}

// Contenu principal de l'accueil
class HomeContent extends StatefulWidget {
  final int streak;
  final String profileImageUrl;
  final VoidCallback onRefreshNeeded;

  const HomeContent({
    super.key,
    required this.streak,
    required this.profileImageUrl,
    required this.onRefreshNeeded,
  });

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  final _user = FirebaseAuth.instance.currentUser;
  final _firestore = FirebaseFirestore.instance;
  final _channel = MethodChannel('com.Phanie.focus_launch/blocker');

  String _pseudo = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (_user == null) return;
    try {
      final doc = await _firestore.collection('users').doc(_user!.uid).get();
      if (doc.exists && mounted) {
        setState(() {
          _pseudo = doc.data()?['pseudo'] ??
              _user!.email?.split('@').first ??
              'Utilisateur';
        });
      }
    } catch (e) {
      debugPrint('Erreur chargement données utilisateur: $e');
    }
  }

  String get _greeting {
    final h = DateTime.now().hour;
    final lang = AppLanguage.instance;
    if (h >= 5 && h < 12) return lang.tr('hello');
    if (h >= 12 && h < 18) return lang.tr('good afternoon');
    return lang.tr('good evening');
  }

  AppLanguage get _lang => AppLanguage.instance;

  Stream<QuerySnapshot> _buildActiveTasksStream() {
    if (_user == null) return const Stream.empty();
    return _firestore
        .collection('users')
        .doc(_user!.uid)
        .collection('tasks')
        .where('status', isEqualTo: 'active')
        .snapshots();
  }

  Stream<QuerySnapshot> _buildAllTasksStream() {
    if (_user == null) return const Stream.empty();
    return _firestore
        .collection('users')
        .doc(_user!.uid)
        .collection('tasks')
        .snapshots();
  }

  void _continueTask(QueryDocumentSnapshot task) async {
    final blockedApps = List<String>.from(task['blockedApps'] ?? []);
    if (blockedApps.isNotEmpty) {
      try {
        await _channel.invokeMethod('startBlocking', {'apps': blockedApps});
      } catch (e) {
        debugPrint('Erreur démarrage blocage: $e');
      }
    }
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SessionScreen(
          taskTitle: task['title'] ?? '',
          durationHours: (task['duration'] ?? 0.0).toDouble(),
          blockedApps: blockedApps,
          taskId: task.id,
        ),
      ),
    );
    widget.onRefreshNeeded();
  }

  void _finishTask(QueryDocumentSnapshot task) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProofScreen(
          taskId: task.id,
          taskTitle: task['title'] ?? 'Tâche sans titre',
        ),
      ),
    );
    widget.onRefreshNeeded();
  }

  Future<void> _refreshData() async {
    await _loadUserData();
    widget.onRefreshNeeded();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F2C),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshData,
          child: StreamBuilder<QuerySnapshot>(
            stream: _buildActiveTasksStream(),
            builder: (context, activeSnap) {
              if (activeSnap.hasError) {
                return _buildErrorWidget(activeSnap.error);
              }

              if (!activeSnap.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              }

              final activeTasks = activeSnap.data!.docs;
              final activeCount = activeTasks.length;

              return StreamBuilder<QuerySnapshot>(
                stream: _buildAllTasksStream(),
                builder: (context, allSnap) {
                  if (allSnap.hasError) {
                    return _buildErrorWidget(allSnap.error);
                  }

                  if (!allSnap.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  }

                  final allTasks = allSnap.data!.docs;
                  final doneCount = allTasks.where((t) => t['status'] == 'done').length;

                  final totalHours = allTasks
                      .where((t) => t['status'] == 'done')
                      .fold<double>(
                    0.0,
                        (sum, t) => sum + ((t['duration'] ?? 0.0) as num).toDouble(),
                  );

                  return Column(
                    children: [
                      _buildTopBar(activeTasks, activeCount),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
                        child: Column(
                          children: [
                            if (activeCount == 0) _buildNoActiveTask(),
                            const SizedBox(height: 14),
                            _buildStatsRow(doneCount, totalHours),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Color(0xFFF5F6FA),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(28),
                              topRight: Radius.circular(28),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _lang.tr('active_tasks'),
                                      style: const TextStyle(
                                        color: Color(0xFF0A0F2C),
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    if (activeCount > 0)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF4FC3F7),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          '$activeCount en cours',
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: activeCount > 0
                                    ? _buildActiveTasksList(activeTasks)
                                    : _buildEmptyState(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget(Object? error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.white.withOpacity(0.7), size: 64),
          const SizedBox(height: 16),
          Text(
            'Erreur de chargement',
            style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            error?.toString().split('\n').first ?? 'Erreur inconnue',
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _refreshData,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0A0F2C),
            ),
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(List<QueryDocumentSnapshot> activeTasks, int activeCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: [
          // Avatar avec photo de profil
          StreamBuilder<DocumentSnapshot>(
            stream: _user != null
                ? _firestore.collection('users').doc(_user!.uid).snapshots()
                : null,
            builder: (context, snapshot) {
              final data = snapshot.data?.data() as Map<String, dynamic>?;
              final imageUrl = data?['profileImageUrl'] ?? widget.profileImageUrl;
              final pseudo = data?['pseudo'] ?? _pseudo;

              return CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFF4FC3F7),
                backgroundImage: imageUrl.isNotEmpty
                    ? NetworkImage(imageUrl)
                    : null,
                child: imageUrl.isEmpty
                    ? Text(
                  pseudo.isNotEmpty ? pseudo[0].toUpperCase() : 'U',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                )
                    : null,
              );
            },
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$_greeting 👋',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.5), fontSize: 11)),
              Text(_pseudo,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900)),
            ],
          ),
          const Spacer(),
          if (activeCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF97316),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.access_time, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Text('$activeCount',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => _showNotifications(activeTasks),
            child: Stack(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                      color: Colors.white.withAlpha(20),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.notifications_outlined,
                      color: Colors.white, size: 20),
                ),
                if (activeCount > 0)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF97316),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: const Color(0xFF0A0F2C), width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoActiveTask() {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreateTaskScreen()),
        );
        widget.onRefreshNeeded();
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF141B3D),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.07),
                  shape: BoxShape.circle),
              child: const Icon(Icons.bolt, color: Color(0xFF4FC3F7), size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_lang.tr('no_active_task'),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                  Text(_lang.tr('tap_to_create'),
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.4), fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                color: Colors.white24, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(int doneCount, double totalHours) {
    return Row(
      children: [
        Expanded(child: _statCard('${widget.streak} 🔥', _lang.tr('streak'))),
        const SizedBox(width: 10),
        Expanded(child: _statCard('$doneCount', _lang.tr('completed'))),
        const SizedBox(width: 10),
        Expanded(
            child: _statCard('${totalHours.toInt()}h', _lang.tr('focus_total'))),
      ],
    );
  }

  Widget _statCard(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFF141B3D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.4), fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildActiveTasksList(List<QueryDocumentSnapshot> activeTasks) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: activeTasks.length,
      itemBuilder: (context, index) {
        final task = activeTasks[index];
        final blockedAppsCount = (task['blockedApps'] as List?)?.length ?? 0;
        final duration = (task['duration'] ?? 0).toDouble();

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            title: Text(task['title'] ?? 'Sans titre',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('$duration h • $blockedAppsCount apps bloquées'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () => _continueTask(task),
                  child: const Text('Continuer',
                      style: TextStyle(
                          color: Colors.green, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => _finishTask(task),
                  child: const Text('Terminer',
                      style: TextStyle(
                          color: Colors.red, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.task_alt, color: Colors.grey.shade300, size: 44),
          const SizedBox(height: 12),
          Text(_lang.tr('no_task_yet'),
              style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(_lang.tr('create_session'),
              style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
        ],
      ),
    );
  }

  void _showNotifications(List<QueryDocumentSnapshot> activeTasks) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _NotificationsSheet(tasks: activeTasks),
    );
  }
}

// ====================== Notifications Sheet ======================
class _NotificationsSheet extends StatelessWidget {
  final List<QueryDocumentSnapshot> tasks;
  const _NotificationsSheet({required this.tasks});

  @override
  Widget build(BuildContext context) {
    final lang = AppLanguage.instance;
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF4F6FB),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${lang.tr("notifications")} (${tasks.length})',
                      style: const TextStyle(
                          color: Color(0xFF0A0F2C),
                          fontSize: 16,
                          fontWeight: FontWeight.w900)),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          shape: BoxShape.circle),
                      child: const Icon(Icons.close,
                          size: 16, color: Colors.black54),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: tasks.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.notifications_none,
                        size: 48, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    const Text('Aucun rappel pour le moment',
                        style: TextStyle(
                            color: Colors.black45, fontSize: 14)),
                  ],
                ),
              )
                  : ListView.separated(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: tasks.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final task = tasks[i];
                  final progress = (task['progress'] ?? 0.0).toDouble();
                  final duration = (task['duration'] ?? 0).toDouble();
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: const Color(0xFFBA7517).withAlpha(60)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                              color: const Color(0xFFFFF3CD),
                              borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.access_time_rounded,
                              color: Color(0xFFBA7517),
                              size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Rappel : ${task['title']}',
                                  style: const TextStyle(
                                      color: Color(0xFF0A0F2C),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 3),
                              Text(
                                  'Progression : ${(progress * 100).toInt()}% — $duration h prévues',
                                  style: const TextStyle(
                                      color: Colors.black45,
                                      fontSize: 11)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}