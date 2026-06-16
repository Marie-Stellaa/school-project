import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'dart:convert';
import 'login_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _user = FirebaseAuth.instance.currentUser;
  final _firestore = FirebaseFirestore.instance;

  Map<String, dynamic>? _userData;
  int _taskCount = 0;
  int _doneCount = 0;

  File? _uploadingPhoto;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadStats();
  }

  Future<void> _loadUserData() async {
    final doc = await _firestore.collection('users').doc(_user?.uid).get();
    if (doc.exists && mounted) setState(() => _userData = doc.data());
  }

  Future<void> _loadStats() async {
    final tasks = await _firestore
        .collection('users').doc(_user?.uid).collection('tasks').get();
    final done = tasks.docs.where((t) => t['status'] == 'done').length;
    if (mounted) setState(() { _taskCount = tasks.docs.length; _doneCount = done; });
  }

  double get _completionRate =>
      _taskCount == 0 ? 0 : (_doneCount / _taskCount) * 100;

  String get _pseudo =>
      _userData?['pseudo'] ?? _user?.displayName ?? 'Utilisateur';

  String get _fullName {
    final p = _userData?['prenom'] ?? _userData?['firstName'] ?? '';
    final n = _userData?['nom'] ?? _userData?['lastName'] ?? '';
    return '$p $n'.trim();
  }

  String? get _photoBase64 => _userData?['photoBase64'];

  String _formatBirthDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      return '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
    } catch (_) { return ''; }
  }

  // ── Upload photo en base64 dans Firestore ─────────────────────────────────
  Future<void> _uploadPhoto(File file) async {
    if (_user == null) return;

    setState(() {
      _uploadingPhoto = file;
      _isUploading = true;
    });

    try {
      // Lire le fichier et convertir en base64
      final bytes = await file.readAsBytes();
      final base64String = base64Encode(bytes);

      // Sauvegarder dans Firestore
      await _firestore.collection('users').doc(_user!.uid).set(
        {'photoBase64': base64String},
        SetOptions(merge: true),
      );

      await _loadUserData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Photo mise à jour ✅'),
          backgroundColor: const Color(0xFF0A0F2C),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur upload : $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() { _uploadingPhoto = null; _isUploading = false; });
    }
  }

  // ── Supprimer la photo ────────────────────────────────────────────────────
  Future<void> _deletePhoto() async {
    if (_user == null) return;

    await _firestore.collection('users').doc(_user!.uid).update(
      {'photoBase64': FieldValue.delete()},
    );

    await _loadUserData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Photo supprimée'),
        backgroundColor: const Color(0xFF0A0F2C),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  // ── Widget avatar ─────────────────────────────────────────────────────────
  Widget _buildAvatar() {
    ImageProvider? imageProvider;

    if (_uploadingPhoto != null) {
      imageProvider = FileImage(_uploadingPhoto!);
    } else if (_photoBase64 != null && _photoBase64!.isNotEmpty) {
      imageProvider = MemoryImage(base64Decode(_photoBase64!));
    }

    return Stack(
      children: [
        CircleAvatar(
          radius: 42,
          backgroundColor: const Color(0xFF4FC3F7),
          backgroundImage: imageProvider,
          child: imageProvider == null
              ? Text(
            _pseudo[0].toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
            ),
          )
              : null,
        ),
        if (_isUploading)
          Positioned.fill(
            child: CircleAvatar(
              radius: 42,
              backgroundColor: Colors.black.withAlpha(100),
              child: const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            ),
          ),
        Positioned(
          bottom: 2,
          right: 2,
          child: Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: Color(0xFF4FC3F7),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
          ),
        ),
      ],
    );
  }

  // ── Modifier le profil ────────────────────────────────────────────────────
  void _showEditProfile() {
    final pseudoCtrl = TextEditingController(text: _userData?['pseudo'] ?? '');
    final prenomCtrl = TextEditingController(text: _userData?['prenom'] ?? _userData?['firstName'] ?? '');
    final nomCtrl = TextEditingController(text: _userData?['nom'] ?? _userData?['lastName'] ?? '');
    DateTime? birthDate;
    final existing = _userData?['birthDate'];
    if (existing != null) { try { birthDate = DateTime.parse(existing); } catch (_) {} }

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setModal) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(color: Color(0xFFF8F9FC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)))),
            const Text('Modifier le profil', style: TextStyle(color: Color(0xFF0A0F2C), fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(height: 20),
            _editField(pseudoCtrl, 'Pseudo', Icons.alternate_email),
            const SizedBox(height: 12),
            _editField(prenomCtrl, 'Prénom', Icons.person_outline),
            const SizedBox(height: 12),
            _editField(nomCtrl, 'Nom', Icons.badge_outlined),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(context: context,
                    initialDate: birthDate ?? DateTime(now.year - 18),
                    firstDate: DateTime(1950), lastDate: DateTime(now.year - 5),
                    builder: (c, child) => Theme(data: Theme.of(c).copyWith(
                        colorScheme: const ColorScheme.light(primary: Color(0xFF0A0F2C), onPrimary: Colors.white)), child: child!));
                if (picked != null) setModal(() => birthDate = picked);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  const Icon(Icons.cake_outlined, color: Color(0xFF0A0F2C), size: 18),
                  const SizedBox(width: 12),
                  Text(
                      birthDate != null
                          ? '${birthDate!.day.toString().padLeft(2,'0')}/${birthDate!.month.toString().padLeft(2,'0')}/${birthDate!.year}'
                          : 'Date de naissance',
                      style: TextStyle(color: birthDate != null ? const Color(0xFF0A0F2C) : Colors.black45, fontSize: 14,
                          fontWeight: birthDate != null ? FontWeight.w600 : FontWeight.normal)),
                  const Spacer(),
                  const Icon(Icons.edit_outlined, color: Colors.black26, size: 16),
                ]),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: () async {
                await _firestore.collection('users').doc(_user?.uid).set({
                  'pseudo': pseudoCtrl.text.trim(),
                  'prenom': prenomCtrl.text.trim(),
                  'nom': nomCtrl.text.trim(),
                  if (birthDate != null) 'birthDate': birthDate!.toIso8601String(),
                }, SetOptions(merge: true));
                await _user?.updateDisplayName(pseudoCtrl.text.trim());
                if (mounted) {
                  Navigator.pop(context);
                  await _loadUserData();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: const Text('Profil mis à jour ✅'),
                    backgroundColor: const Color(0xFF0A0F2C),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0A0F2C),
                  foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            )),
            const SizedBox(height: 8),
          ])),
        ),
      )),
    );
  }

  // ── Options photo ─────────────────────────────────────────────────────────
  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4))),
          const Text('Photo de profil',
              style: TextStyle(color: Color(0xFF0A0F2C), fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          _photoOption(icon: Icons.camera_alt_outlined, label: 'Prendre une photo', onTap: () async {
            Navigator.pop(context);
            final img = await ImagePicker().pickImage(
              source: ImageSource.camera,
              imageQuality: 50,
              maxWidth: 300,
            );
            if (img != null && mounted) await _uploadPhoto(File(img.path));
          }),
          const SizedBox(height: 8),
          _photoOption(icon: Icons.photo_library_outlined, label: 'Choisir depuis la galerie', onTap: () async {
            Navigator.pop(context);
            final img = await ImagePicker().pickImage(
              source: ImageSource.gallery,
              imageQuality: 50,
              maxWidth: 300,
            );
            if (img != null && mounted) await _uploadPhoto(File(img.path));
          }),
          if (_photoBase64 != null) ...[
            const SizedBox(height: 8),
            _photoOption(
              icon: Icons.delete_outline,
              label: 'Supprimer la photo',
              isRed: true,
              onTap: () async {
                Navigator.pop(context);
                await _deletePhoto();
              },
            ),
          ],
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  // ── Mot de passe ──────────────────────────────────────────────────────────
  void _showChangePassword() {
    final curCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final conCtrl = TextEditingController();
    bool obscCur = true, obscNew = true, obscCon = true;

    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setModal) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(color: Color(0xFFF8F9FC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)))),
            const Text('Changer le mot de passe', style: TextStyle(color: Color(0xFF0A0F2C), fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(height: 20),
            _pwField(curCtrl, 'Mot de passe actuel', obscCur, () => setModal(() => obscCur = !obscCur)),
            const SizedBox(height: 12),
            _pwField(newCtrl, 'Nouveau mot de passe', obscNew, () => setModal(() => obscNew = !obscNew)),
            const SizedBox(height: 12),
            _pwField(conCtrl, 'Confirmer le mot de passe', obscCon, () => setModal(() => obscCon = !obscCon)),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: () async {
                if (newCtrl.text != conCtrl.text) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Les mots de passe ne correspondent pas'), backgroundColor: Color(0xFFE24B4A)));
                  return;
                }
                try {
                  final cred = EmailAuthProvider.credential(email: _user!.email!, password: curCtrl.text);
                  await _user!.reauthenticateWithCredential(cred);
                  await _user!.updatePassword(newCtrl.text);
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: const Text('Mot de passe mis à jour ✅'),
                        backgroundColor: const Color(0xFF0A0F2C), behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
                  }
                } catch (_) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Mot de passe actuel incorrect'), backgroundColor: Color(0xFFE24B4A)));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0A0F2C),
                  foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Mettre à jour', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            )),
            const SizedBox(height: 8),
          ]),
        ),
      )),
    );
  }

  // ── Noter l'appli ─────────────────────────────────────────────────────────
  void _rateApp() {
    const androidUrl = 'https://play.google.com/store/apps/details?id=com.ton.focuslock';
    const iosUrl = 'https://apps.apple.com/app/focuslock/id000000000';
    showModalBottomSheet(context: context, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4))),
        const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.star_rounded, color: Color(0xFFFFB800), size: 36),
          Icon(Icons.star_rounded, color: Color(0xFFFFB800), size: 36),
          Icon(Icons.star_rounded, color: Color(0xFFFFB800), size: 36),
          Icon(Icons.star_rounded, color: Color(0xFFFFB800), size: 36),
          Icon(Icons.star_outline_rounded, color: Color(0xFFFFB800), size: 36),
        ]),
        const SizedBox(height: 14),
        const Text('Tu aimes FocusLock ?', style: TextStyle(color: Color(0xFF0A0F2C), fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        const Text('Laisse-nous une note, ça nous aide beaucoup !', textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black45, fontSize: 13)),
        const SizedBox(height: 24),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF0A0F2C),
                  side: const BorderSide(color: Color(0xFF0A0F2C)), padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Plus tard'))),
          const SizedBox(width: 12),
          Expanded(child: ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final url = Uri.parse(Platform.isAndroid ? androidUrl : iosUrl);
              if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0A0F2C),
                foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Noter ⭐', style: TextStyle(fontWeight: FontWeight.w700)),
          )),
        ]),
        const SizedBox(height: 8),
      ])),
    );
  }

  // ── Déconnexion ───────────────────────────────────────────────────────────
  void _logout() {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: Colors.white,
      title: const Text('Déconnexion', style: TextStyle(color: Color(0xFF0A0F2C), fontWeight: FontWeight.w900)),
      content: const Text('Tu vas être déconnecté(e).'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('Annuler', style: TextStyle(color: Colors.black45))),
        ElevatedButton(
          onPressed: () async {
            await FirebaseAuth.instance.signOut();
            if (mounted) Navigator.pushAndRemoveUntil(context,
                MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
          },
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0A0F2C)),
          child: const Text('Déconnecter', style: TextStyle(color: Colors.white)),
        ),
      ],
    ));
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  color: const Color(0xFF0A0F2C),
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 56),
                  child: Column(children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(width: 34, height: 34,
                            decoration: BoxDecoration(color: Colors.white.withAlpha(20), shape: BoxShape.circle),
                            child: const Icon(Icons.arrow_back, color: Colors.white, size: 16)),
                      ),
                      const Text('Mon Profil', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
                      GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
                        child: Container(width: 34, height: 34,
                            decoration: BoxDecoration(color: Colors.white.withAlpha(20), shape: BoxShape.circle),
                            child: const Icon(Icons.settings, color: Colors.white, size: 16)),
                      ),
                    ]),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: _isUploading ? null : _showPhotoOptions,
                      child: _buildAvatar(),
                    ),
                    const SizedBox(height: 10),
                    Text(_fullName.isNotEmpty ? _fullName : _pseudo,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text('@$_pseudo', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                    if (_userData?['birthDate'] != null) ...[
                      const SizedBox(height: 6),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.cake_outlined, color: Colors.white38, size: 13),
                        const SizedBox(width: 4),
                        Text(_formatBirthDate(_userData!['birthDate']),
                            style: const TextStyle(color: Colors.white38, fontSize: 12)),
                      ]),
                    ],
                  ]),
                ),
                Positioned(
                  bottom: -36, left: 16, right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 20)],
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                      _stat('$_taskCount', 'Tâches'),
                      Container(width: 1, height: 30, color: Colors.grey.shade200),
                      _stat('$_doneCount', 'Terminées ✅'),
                      Container(width: 1, height: 30, color: Colors.grey.shade200),
                      _stat('${_completionRate.toInt()}%', 'Taux'),
                    ]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 56),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _showEditProfile,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Modifier le profil', style: TextStyle(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0A0F2C),
                      foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _sectionTitle('MON COMPTE'),
            _optionsCard([
              _option(icon: Icons.edit_outlined, iconBg: const Color(0xFFEEF2FF), iconColor: const Color(0xFF0A0F2C),
                  label: 'Modifier mon profil', subtitle: 'Pseudo, prénom, date de naissance', onTap: _showEditProfile),
              _option(icon: Icons.camera_alt_outlined, iconBg: const Color(0xFFE6F1FB), iconColor: const Color(0xFF185FA5),
                  label: 'Photo de profil', subtitle: 'Changer ma photo', onTap: _showPhotoOptions),
              _option(icon: Icons.key_outlined, iconBg: const Color(0xFFFFF3CD), iconColor: const Color(0xFFBA7517),
                  label: 'Mot de passe', subtitle: 'Modifier mon mot de passe', onTap: _showChangePassword),
            ]),
            const SizedBox(height: 16),
            _sectionTitle('APPLICATION'),
            _optionsCard([
              _option(icon: Icons.settings_outlined, iconBg: const Color(0xFFF5F6FA), iconColor: const Color(0xFF0A0F2C),
                  label: 'Paramètres', subtitle: 'Notifications, langue, mode strict',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()))),
              _option(icon: Icons.star_outline_rounded, iconBg: const Color(0xFFFFF3CD), iconColor: const Color(0xFFBA7517),
                  label: 'Noter FocusLock', subtitle: 'Laisse-nous un avis ⭐', onTap: _rateApp),
            ]),
            const SizedBox(height: 16),
            _sectionTitle('COMPTE'),
            _optionsCard([
              _option(icon: Icons.logout, iconBg: const Color(0xFFFFE0E0), iconColor: const Color(0xFFE24B4A),
                  label: 'Se déconnecter', isRed: true, onTap: _logout),
            ]),
            const SizedBox(height: 30),
          ]),
        ),
      ),
    );
  }

  // ── Widgets helpers ───────────────────────────────────────────────────────
  Widget _stat(String value, String label) => Column(children: [
    Text(value, style: const TextStyle(color: Color(0xFF0A0F2C), fontSize: 20, fontWeight: FontWeight.w900)),
    Text(label, style: const TextStyle(color: Colors.black45, fontSize: 10)),
  ]);

  Widget _sectionTitle(String t) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
    child: Align(alignment: Alignment.centerLeft,
        child: Text(t, style: const TextStyle(color: Colors.black45, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5))),
  );

  Widget _optionsCard(List<Widget> children) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
    child: Column(children: children),
  );

  Widget _option({required IconData icon, required Color iconBg, required Color iconColor,
    required String label, String? subtitle, bool isRed = false, required VoidCallback onTap}) {
    return GestureDetector(onTap: onTap, child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
      child: Row(children: [
        Container(width: 36, height: 36, decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor, size: 18)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: isRed ? const Color(0xFFE24B4A) : const Color(0xFF0A0F2C),
              fontSize: 13, fontWeight: FontWeight.w700)),
          if (subtitle != null) Text(subtitle, style: const TextStyle(color: Colors.black38, fontSize: 11)),
        ])),
        Icon(Icons.chevron_right, color: isRed ? const Color(0xFFE24B4A) : Colors.black26, size: 18),
      ]),
    ));
  }

  Widget _editField(TextEditingController ctrl, String label, IconData icon) =>
      Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: TextField(controller: ctrl,
              style: const TextStyle(color: Color(0xFF0A0F2C), fontSize: 14, fontWeight: FontWeight.w600),
              decoration: InputDecoration(labelText: label,
                  labelStyle: const TextStyle(color: Colors.black45, fontSize: 12),
                  prefixIcon: Icon(icon, color: const Color(0xFF0A0F2C), size: 18),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14))));

  Widget _photoOption({required IconData icon, required String label, required VoidCallback onTap, bool isRed = false}) =>
      GestureDetector(onTap: onTap, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(color: isRed ? const Color(0xFFFFE0E0) : const Color(0xFFF5F6FA),
              borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Icon(icon, color: isRed ? const Color(0xFFE24B4A) : const Color(0xFF0A0F2C), size: 20),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(color: isRed ? const Color(0xFFE24B4A) : const Color(0xFF0A0F2C),
                fontWeight: FontWeight.w600, fontSize: 14)),
          ])));

  Widget _pwField(TextEditingController ctrl, String label, bool obscure, VoidCallback toggle) =>
      Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: TextField(controller: ctrl, obscureText: obscure,
              style: const TextStyle(color: Color(0xFF0A0F2C), fontSize: 14),
              decoration: InputDecoration(labelText: label,
                  labelStyle: const TextStyle(color: Colors.black45, fontSize: 12),
                  prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF0A0F2C), size: 18),
                  suffixIcon: GestureDetector(onTap: toggle,
                      child: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          color: Colors.black45, size: 18)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14))));
}