import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'app_langage.dart';
import 'proof_screen.dart';

class SessionScreen extends StatefulWidget {
  final String taskTitle;
  final double durationHours;
  final List<String> blockedApps;
  final String taskId;

  const SessionScreen({
    super.key,
    required this.taskTitle,
    required this.durationHours,
    required this.blockedApps,
    required this.taskId,
  });

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen>
    with SingleTickerProviderStateMixin {

      static const _channel =
      MethodChannel('com.Phanie.focus_launch/blocker');

  late int _totalSeconds;
  late int _secondsLeft;
  Timer? _timer;
  late AnimationController _pulseController;
  final _user = FirebaseAuth.instance.currentUser;
  final _firestore = FirebaseFirestore.instance;
  AppLanguage get _lang => AppLanguage.instance;
      static const Map<String, String> _knownPackages = {
        'com.zhiliaoapp.musically': 'TikTok',
        'com.instagram.android':    'Instagram',
        'com.google.android.youtube': 'YouTube',
        'com.twitter.android':      'Twitter',
        'com.facebook.katana':      'Facebook',
        'com.snapchat.android':     'Snapchat',
      };

      String _packageToName(String package) {
        return _knownPackages[package] ?? package;
      }

  bool _isBlockingActive = false;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();

    // Vérification que taskId n'est pas vide
    if (widget.taskId.isEmpty) {
      print('ERREUR: taskId est vide dans SessionScreen');
      Future.microtask(() {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erreur: ID de tâche invalide')),
          );
          Navigator.pop(context);
        }
      });
      return;
    }

    _totalSeconds = (widget.durationHours * 3600).toInt();
    _secondsLeft = _totalSeconds;
    _pulseController = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);

    _startTimer();
    _startBlocking();
  }

  // ===== BLOCAGE =====
  Future<void> _startBlocking() async {
    if (widget.blockedApps.isEmpty) {
      setState(() {
        _isBlockingActive = false;
      });
      return;
    }

    try {
      final result = await _channel.invokeMethod('startBlocking', {
        'apps': widget.blockedApps,
      });

      setState(() {
        _isBlockingActive = true;
      });

      if (result == 'open_settings' && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                '⚙️ Active Focus Launch dans Accessibilité pour bloquer les apps'),
            backgroundColor: const Color(0xFF0A0F2C),
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      print('Erreur startBlocking: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Impossible de bloquer les apps: $e'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _stopBlocking() async {
    if (!_isBlockingActive) return;

    try {
      await _channel.invokeMethod('stopBlocking');
      setState(() {
        _isBlockingActive = false;
      });
    } catch (e) {
      print('Erreur stopBlocking: $e');
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_secondsLeft > 0) {
        setState(() => _secondsLeft--);

        // Mettre à jour Firestore toutes les 30 secondes
        if (_secondsLeft % 30 == 0 && _secondsLeft > 0) {
          final progress = (_totalSeconds - _secondsLeft) / _totalSeconds;
          _updateProgress(progress);
        }
      } else {
        timer.cancel();
        _sessionDone();
      }
    });
  }

  // ← NOUVELLE méthode pour mettre à jour la progression
  Future<void> _updateProgress(double progress) async {
    if (widget.taskId.isEmpty) return;

    try {
      await _firestore
          .collection('users')
          .doc(_user?.uid)
          .collection('tasks')
          .doc(widget.taskId)
          .update({'progress': progress});
    } catch (e) {
      print('Erreur mise à jour progression: $e');
    }
  }

  Future<void> _sessionDone() async {
    if (_isNavigating) return;
    _isNavigating = true;


    _timer?.cancel();

    await _stopBlocking();

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ProofScreen(
            taskTitle: widget.taskTitle,
            taskId: widget.taskId,
          ),
        ),
      );
    }
  }


  Future<void> _quitSession() async {
    if (_isNavigating) return;
    _isNavigating = true;

    final shouldQuit = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0A0F2C),
        title: Text(_lang.tr('quit_session'),
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900)),
        content: Text(_lang.tr('progress_lost'),
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_lang.tr('continue_btn'),
                style: const TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red),
            child: Text(_lang.tr('quit')),
          ),
        ],
      ),
    );

    if (shouldQuit == true) {
      _timer?.cancel();
      await _stopBlocking();
      if (mounted) {
        Navigator.pop(context);
      }
    } else {
      _isNavigating = false;
    }
  }

  String _formatTime(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  double get _progress {
    if (_totalSeconds <= 0) return 0;
    return (_totalSeconds - _secondsLeft) / _totalSeconds;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _stopBlocking();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    if (widget.taskId.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0F2C),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Erreur: ID de tâche manquant',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4FC3F7),
                ),
                child: const Text('Retour'),
              ),
            ],
          ),
        ),
      );
    }

    return ListenableBuilder(
      listenable: AppLanguage.instance,
      builder: (context, _) {
        return PopScope(
          canPop: false,
          onPopInvoked: (didPop) async {
            if (!didPop) {
              await _quitSession();
            }
          },
          child: Scaffold(
            backgroundColor: const Color(0xFF0A0F2C),
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(children: [

                  Row(children: [
                    GestureDetector(
                      onTap: _quitSession,
                      child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                              color: Colors.white.withAlpha(20),
                              shape: BoxShape.circle),
                          child: const Icon(Icons.close,
                              color: Colors.white, size: 18)),
                    ),
                    const Spacer(),
                    Text(_lang.tr('session_active'),
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 14)),
                    const Spacer(),

                    if (widget.blockedApps.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _isBlockingActive
                              ? Colors.green.withAlpha(40)
                              : Colors.red.withAlpha(40),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: (_isBlockingActive ? Colors.green : Colors.red).withAlpha(80)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                    color: _isBlockingActive ? Colors.green : Colors.red,
                                    shape: BoxShape.circle)),
                            const SizedBox(width: 4),
                            Text(
                              _isBlockingActive ? 'Bloqué' : 'Blocage inactif',
                              style: TextStyle(
                                  color: _isBlockingActive ? Colors.green : Colors.red,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      )
                    else
                      const SizedBox(width: 36),
                  ]),

                  const Spacer(flex: 2),

                  Text(widget.taskTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text(_lang.tr('you_can'),
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 14)),

                  const Spacer(flex: 2),


                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) => Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: Colors.white.withAlpha(
                                    (_pulseController.value * 20)
                                        .toInt()),
                                blurRadius: 30,
                                spreadRadius: 5)
                          ]),
                      child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                                width: 220,
                                height: 220,
                                child: CircularProgressIndicator(
                                    value: _progress,
                                    strokeWidth: 12,
                                    backgroundColor:
                                    Colors.white.withAlpha(20),
                                    valueColor:
                                    const AlwaysStoppedAnimation<
                                        Color>(Colors.white))),
                            Column(
                                mainAxisAlignment:
                                MainAxisAlignment.center,
                                children: [
                                  Text(_formatTime(_secondsLeft),
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 42,
                                          fontWeight: FontWeight.w200,
                                          letterSpacing: 4)),
                                  const SizedBox(height: 4),
                                  Text(
                                      '${(_progress * 100).toInt()}% accompli',
                                      style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 12)),
                                ]),
                          ]),
                    ),
                  ),

                  const Spacer(flex: 2),

                  if (widget.blockedApps.isNotEmpty) ...[
                    Text(
                        _lang
                            .tr('apps_to_block')
                            .replaceAll('🔒 ', ''),
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 12)),
                    const SizedBox(height: 10),
                    Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: widget.blockedApps
                            .map((app) => Container(
                          padding:
                          const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6),
                          decoration: BoxDecoration(
                              color:
                              Colors.white.withAlpha(15),
                              borderRadius:
                              BorderRadius.circular(20),
                              border: Border.all(
                                  color: Colors.white
                                      .withAlpha(30))),
                          child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.block,
                                    color: Colors.red,
                                    size: 12),
                                const SizedBox(width: 4),
                               Text(_packageToName(app),
                               style: const TextStyle(
                                   color: Colors.white70,
                                   fontSize: 12)),
                              ]),
                        ))
                            .toList()),
                  ],

                  const Spacer(flex: 2),

                  TextButton(
                    onPressed: _sessionDone,
                    child: Text(
                      _lang.tr('finish_session'),
                      style: const TextStyle(color: Colors.white30, fontSize: 13),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }
}