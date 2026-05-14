import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import 'app_langage.dart';
import 'home_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  AppLanguage get _lang => AppLanguage.instance;

  @override
  void dispose() { _emailCtrl.dispose(); _passwordCtrl.dispose(); super.dispose(); }

  void _login() async {
    if (_formKey.currentState!.validate()) {
      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: _emailCtrl.text.trim(), password: _passwordCtrl.text);
        if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      } on FirebaseAuthException catch (e) {
        String message = 'Une erreur est survenue';
        if (e.code == 'user-not-found') message = 'Aucun compte avec cet email';
        else if (e.code == 'wrong-password') message = 'Mot de passe incorrect';
        else if (e.code == 'invalid-credential') message = 'Email ou mot de passe incorrect';
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLanguage.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: Colors.white,
          body: Stack(children: [
            _buildClock(top: 60, left: 20, size: 55, hourAngle: 0.3, minAngle: 0.7, opacity: 0.08),
            _buildClock(top: 40, right: 20, size: 44, hourAngle: 0.9, minAngle: 0.2, opacity: 0.07),
            _buildClock(bottom: 60, right: 10, size: 70, hourAngle: 0.5, minAngle: 1.1, opacity: 0.05),
            _buildClock(bottom: 80, left: 10, size: 50, hourAngle: 0.1, minAngle: 0.8, opacity: 0.05),
            SafeArea(child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
                const SizedBox(height: 60),
                const Icon(Icons.lock_rounded, color: Color(0xFF0A0F2C), size: 50),
                const SizedBox(height: 12),
                Text(_lang.tr('welcome_back'), style: const TextStyle(color: Color(0xFF0A0F2C),
                    fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2)),
                const SizedBox(height: 6),
                Text(_lang.tr('connect'), style: const TextStyle(color: Colors.black45, fontSize: 14)),
                const SizedBox(height: 40),
                _buildField(_lang.tr('email'), _emailCtrl, icon: Icons.email_outlined,
                    validator: (value) {
                      final v = value?.trim();
                      if (v == null || v.isEmpty) return '${_lang.tr("email")} requis';
                      if (!RegExp(r'^[\w.-]+@[\w.-]+\.[a-zA-Z]{2,}$').hasMatch(v)) return 'Email invalide';
                      return null;
                    }),
                _buildField(_lang.tr('password'), _passwordCtrl, icon: Icons.lock_outline, isPassword: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Mot de passe requis';
                      if (value.length < 6) return 'Minimum 6 caractères';
                      return null;
                    }),
                Align(alignment: Alignment.centerRight,
                    child: GestureDetector(onTap: () {},
                        child: Text(_lang.tr('forgot_password'), style: const TextStyle(
                            color: Color(0xFF0A0F2C), fontSize: 13, fontWeight: FontWeight.w900,
                            decoration: TextDecoration.underline)))),
                const SizedBox(height: 24),
                SizedBox(width: double.infinity, child: ElevatedButton(
                  onPressed: _login,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0A0F2C),
                      foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  child: Text(_lang.tr('connect'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                )),
                const SizedBox(height: 24),
                Row(children: [
                  Expanded(child: Divider(color: Colors.grey.shade200)),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('ou', style: TextStyle(color: Colors.black26))),
                  Expanded(child: Divider(color: Colors.grey.shade200)),
                ]),
                const SizedBox(height: 20),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(_lang.tr('no_account'), style: const TextStyle(color: Colors.black45)),
                  GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                      child: Text(_lang.tr('sign_up'), style: const TextStyle(color: Color(0xFF0A0F2C),
                          fontWeight: FontWeight.w900, decoration: TextDecoration.underline))),
                ]),
                const SizedBox(height: 30),
              ])),
            )),
          ]),
        );
      },
    );
  }

  Widget _buildField(String label, TextEditingController ctrl,
      {bool isPassword = false, required IconData icon, String? Function(String?)? validator}) {
    return Padding(padding: const EdgeInsets.only(bottom: 16),
        child: TextFormField(controller: ctrl, obscureText: isPassword && _obscure,
            style: const TextStyle(color: Color(0xFF0A0F2C), fontWeight: FontWeight.w500),
            decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: Colors.black45),
                prefixIcon: Icon(icon, color: const Color(0xFF0A0F2C), size: 20),
                filled: true, fillColor: const Color(0xFFF5F6FA),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF0A0F2C), width: 1.5)),
                errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red)),
                focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red)),
                suffixIcon: isPassword ? IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: const Color(0xFF0A0F2C), size: 20),
                    onPressed: () => setState(() => _obscure = !_obscure)) : null),
            validator: validator));
  }

  Widget _buildClock({required double size, required double hourAngle, required double minAngle,
    required double opacity, double? top, double? bottom, double? left, double? right}) {
    return Positioned(top: top, bottom: bottom, left: left, right: right,
        child: Opacity(opacity: opacity, child: SizedBox(width: size, height: size,
            child: CustomPaint(painter: _ClockPainter(hourAngle: hourAngle, minAngle: minAngle)))));
  }
}

class _ClockPainter extends CustomPainter {
  final double hourAngle, minAngle;
  _ClockPainter({required this.hourAngle, required this.minAngle});
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    canvas.drawCircle(center, radius - 1, Paint()..color = const Color(0xFF0A0F2C)..style = PaintingStyle.stroke..strokeWidth = 2.5);
    canvas.drawLine(center, Offset(center.dx + (radius * 0.5) * sin(hourAngle * 2 * pi), center.dy - (radius * 0.5) * cos(hourAngle * 2 * pi)),
        Paint()..color = const Color(0xFF0A0F2C)..strokeWidth = 3..strokeCap = StrokeCap.round);
    canvas.drawLine(center, Offset(center.dx + (radius * 0.7) * sin(minAngle * 2 * pi), center.dy - (radius * 0.7) * cos(minAngle * 2 * pi)),
        Paint()..color = const Color(0xFF0A0F2C)..strokeWidth = 2..strokeCap = StrokeCap.round);
    canvas.drawCircle(center, 3, Paint()..color = const Color(0xFF0A0F2C));
  }
  @override
  bool shouldRepaint(_ClockPainter old) => false;
}