import 'package:flutter/material.dart';
import 'dart:async';
import 'app_langage.dart';
import 'register_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {

  final String _fullText = 'Tu travailles ? Prouve-le nous!';
  String _displayedText = '';
  bool _showCursor = true;
  int _charIndex = 0;
  Timer? _typeTimer;
  Timer? _cursorTimer;
  AppLanguage get _lang => AppLanguage.instance;

  @override
  void initState() {
    super.initState();
    _cursorTimer = Timer.periodic(const Duration(milliseconds: 500),
            (t) { if (mounted) setState(() => _showCursor = !_showCursor); });
    Future.delayed(const Duration(milliseconds: 800), _startTyping);
  }

  void _startTyping() {
    _typeTimer = Timer.periodic(const Duration(milliseconds: 80), (timer) {
      if (!mounted) { timer.cancel(); return; }
      if (_charIndex < _fullText.length) {
        setState(() { _displayedText = _fullText.substring(0, _charIndex); _charIndex++; });
      } else { timer.cancel(); }
    });
  }

  @override
  void dispose() { _typeTimer?.cancel(); _cursorTimer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLanguage.instance,
      builder: (context, _) {
        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(gradient: RadialGradient(
                center: Alignment.center, radius: 1.2,
                colors: [Color(0xFF0D2166), Color(0xFF060D2E)])),
            child: SafeArea(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.lock_clock_rounded, color: Colors.white, size: 90),
                const SizedBox(height: 40),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Flexible(child: Text(_displayedText, textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 28,
                          fontWeight: FontWeight.w900, height: 1.3))),
                  Text(_showCursor ? '|' : ' ',
                      style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
                ]),
                const SizedBox(height: 80),
                SizedBox(width: double.infinity, child: ElevatedButton(
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const RegisterScreen())),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF060D2E), padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                  child: const Text('Commencer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                )),
              ]),
            )),
          ),
        );
      },
    );
  }
}