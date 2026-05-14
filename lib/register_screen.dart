import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_langage.dart';
import 'login_screen.dart';
import 'home_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _pseudoCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  bool _obscure = true;
  bool _obscure2 = true;
  DateTime? _birthDate;
  AppLanguage get _lang => AppLanguage.instance;

  @override
  void dispose() {
    _firstNameCtrl.dispose(); _lastNameCtrl.dispose(); _pseudoCtrl.dispose();
    _emailCtrl.dispose(); _passwordCtrl.dispose(); _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(context: context,
        initialDate: DateTime(now.year - 16), firstDate: DateTime(1950), lastDate: DateTime(now.year - 5),
        builder: (context, child) => Theme(
            data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(primary: Color(0xFF0A0F2C), onPrimary: Colors.white)),
            child: child!));
    if (picked != null) setState(() => _birthDate = picked);
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2,'0')}/${date.month.toString().padLeft(2,'0')}/${date.year}';

  void _register() async {
    if (_birthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_lang.tr('birth_date'))));
      return;
    }
    if (_formKey.currentState!.validate()) {
      try {
        final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: _emailCtrl.text.trim(), password: _passwordCtrl.text);
        final fullName = '${_firstNameCtrl.text.trim()} ${_lastNameCtrl.text.trim()}';
        await credential.user?.updateDisplayName(fullName);
        await FirebaseFirestore.instance.collection('users').doc(credential.user?.uid).set({
          'firstName': _firstNameCtrl.text.trim(),
          'lastName': _lastNameCtrl.text.trim(),
          'pseudo': _pseudoCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'birthDate': _birthDate!.toIso8601String(),
          'createdAt': FieldValue.serverTimestamp(),
        });
        if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      } on FirebaseAuthException catch (e) {
        String message = 'Une erreur est survenue';
        if (e.code == 'email-already-in-use') message = 'Cet email est déjà utilisé';
        else if (e.code == 'weak-password') message = 'Mot de passe trop faible';
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
          backgroundColor: const Color(0xFF0A0F2C),
          body: Column(children: [
            Expanded(flex: 3, child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const SizedBox(height: 40),
              const Icon(Icons.lock_rounded, color: Colors.white, size: 50),
              const SizedBox(height: 12),
              const Text('WELCOME !', style: TextStyle(color: Colors.white, fontSize: 26,
                  fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            ]))),
            Expanded(flex: 7, child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(color: Colors.white,
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30))),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
                child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_lang.tr('create_account'), style: const TextStyle(color: Color(0xFF0A0F2C),
                      fontSize: 24, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(_lang.tr('join'), style: const TextStyle(color: Colors.black45, fontSize: 14)),
                  const SizedBox(height: 24),
                  Row(children: [
                    Expanded(child: _buildField(_lang.tr('first_name'), _firstNameCtrl,
                        icon: Icons.person_outline, validator: (v) {
                          final s = v?.trim();
                          if (s == null || s.isEmpty) return 'Requis';
                          if (s.length < 2) return 'Trop court';
                          if (!RegExp(r'^[a-zA-ZÀ-ÿ\s]+$').hasMatch(s)) return 'Invalide';
                          return null;
                        })),
                    const SizedBox(width: 12),
                    Expanded(child: _buildField(_lang.tr('last_name'), _lastNameCtrl,
                        icon: Icons.person_outline, validator: (v) {
                          final s = v?.trim();
                          if (s == null || s.isEmpty) return 'Requis';
                          if (s.length < 2) return 'Trop court';
                          return null;
                        })),
                  ]),
                  _buildField(_lang.tr('pseudo'), _pseudoCtrl, icon: Icons.alternate_email,
                      validator: (v) {
                        final s = v?.trim();
                        if (s == null || s.isEmpty) return 'Pseudonyme requis';
                        if (s.length < 3) return 'Minimum 3 caractères';
                        if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(s)) return 'Lettres, chiffres et _ uniquement';
                        return null;
                      }),
                  GestureDetector(
                    onTap: _pickDate,
                    child: Container(margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                        decoration: BoxDecoration(color: const Color(0xFFF5F6FA), borderRadius: BorderRadius.circular(12)),
                        child: Row(children: [
                          const Icon(Icons.cake_outlined, color: Color(0xFF0A0F2C), size: 20),
                          const SizedBox(width: 12),
                          Text(_birthDate != null ? _formatDate(_birthDate!) : _lang.tr('birth_date'),
                              style: TextStyle(color: _birthDate != null ? const Color(0xFF0A0F2C) : Colors.black45,
                                  fontSize: 16, fontWeight: _birthDate != null ? FontWeight.w500 : FontWeight.normal)),
                        ])),
                  ),
                  _buildField(_lang.tr('email'), _emailCtrl, icon: Icons.email_outlined,
                      validator: (v) {
                        final s = v?.trim();
                        if (s == null || s.isEmpty) return 'Email requis';
                        if (!RegExp(r'^[\w.-]+@[\w.-]+\.[a-zA-Z]{2,}$').hasMatch(s)) return 'Email invalide';
                        return null;
                      }),
                  _buildField(_lang.tr('password'), _passwordCtrl, icon: Icons.lock_outline, isPassword: true,
                      validator: (v) {
                        final s = v ?? '';
                        if (s.isEmpty) return 'Mot de passe requis';
                        if (s.length < 6) return 'Minimum 6 caractères';
                        if (!RegExp(r'[A-Z]').hasMatch(s)) return 'Au moins une majuscule';
                        if (!RegExp(r'[0-9]').hasMatch(s)) return 'Au moins un chiffre';
                        return null;
                      }),
                  _buildField(_lang.tr('confirm_password'), _confirmPasswordCtrl, icon: Icons.lock_outline, isConfPassword: true,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Confirmation requise';
                        if (v != _passwordCtrl.text) return 'Les mots de passe ne correspondent pas';
                        return null;
                      }),
                  const SizedBox(height: 8),
                  SizedBox(width: double.infinity, child: ElevatedButton(
                    onPressed: _register,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0A0F2C),
                        foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    child: Text(_lang.tr('sign_up'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  )),
                  const SizedBox(height: 20),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(_lang.tr('already_account'), style: const TextStyle(color: Colors.black45)),
                    GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                        child: Text(_lang.tr('connect'), style: const TextStyle(color: Color(0xFF0A0F2C),
                            fontWeight: FontWeight.w900, decoration: TextDecoration.underline))),
                  ]),
                ])),
              ),
            )),
          ]),
        );
      },
    );
  }

  Widget _buildField(String label, TextEditingController ctrl,
      {bool isPassword = false, bool isConfPassword = false, required IconData icon, String? Function(String?)? validator}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
          controller: ctrl,
          obscureText: (isPassword && _obscure) || (isConfPassword && _obscure2),
          style: const TextStyle(color: Color(0xFF0A0F2C), fontWeight: FontWeight.w500),
          decoration: InputDecoration(
              labelText: label,
              labelStyle: const TextStyle(color: Colors.black45),
              prefixIcon: Icon(icon, color: const Color(0xFF0A0F2C), size: 20),
              filled: true,
              fillColor: const Color(0xFFF5F6FA),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF0A0F2C), width: 1.5)
              ),
              errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.red)
              ),
              focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.red)
              ),
              suffixIcon: isPassword || isConfPassword ? IconButton(
                  icon: Icon(
                      (isPassword && _obscure) || (isConfPassword && _obscure2)
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: const Color(0xFF0A0F2C),
                      size: 20
                  ),
                  onPressed: () => setState(() {
                    if (isPassword) {
                      _obscure = !_obscure;
                    } else if (isConfPassword) {
                      _obscure2 = !_obscure2;
                    }
                  })
              ) : null
          ),
          validator: validator
      ),
    );
  }
  }
