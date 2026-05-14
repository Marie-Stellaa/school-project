import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'app_langage.dart';
import 'home_screen.dart';

class ProofScreen extends StatefulWidget {
  final String taskTitle;
  final String taskId;
  const ProofScreen({super.key, required this.taskTitle, required this.taskId});

  @override
  State<ProofScreen> createState() => _ProofScreenState();
}

class _ProofScreenState extends State<ProofScreen> {
  File? _proofImage;
  final _picker = ImagePicker();
  bool _submitted = false;
  final _user = FirebaseAuth.instance.currentUser;
  final _firestore = FirebaseFirestore.instance;
  AppLanguage get _lang => AppLanguage.instance;

  Future<void> _pickImage(ImageSource source) async {
    final xfile = await _picker.pickImage(source: source, imageQuality: 80);
    if (xfile != null) setState(() => _proofImage = File(xfile.path));
  }

  Future<void> _submitProof() async {
    if (_proofImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_lang.tr('add_proof') ?? 'Veuillez ajouter une photo')),
      );
      return;
    }

    setState(() => _submitted = true);

    try {
      await _firestore
          .collection('users')
          .doc(_user?.uid)
          .collection('tasks')
          .doc(widget.taskId)
          .update({
        'status': 'done',
        'progress': 1.0,
        'completedAt': FieldValue.serverTimestamp(),
        'proofSubmittedAt': FieldValue.serverTimestamp(),
      });

      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {

        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitted = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la validation : $e')),
        );
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
          appBar: AppBar(
            backgroundColor: const Color(0xFF0A0F2C),
            elevation: 0,
            leading: _submitted
                ? null
                : IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context)),
            title: Text(_lang.tr('proof_title'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          ),
          body: _submitted ? _buildSuccess() : _buildForm(),
        );
      },
    );
  }

  Widget _buildSuccess() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(color: Colors.green.withAlpha(30), shape: BoxShape.circle),
          child: const Icon(Icons.check_circle_outline, color: Colors.green, size: 60),
        ),
        const SizedBox(height: 24),
        Text(_lang.tr('task_validated'),
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(_lang.tr('great_job'), style: const TextStyle(color: Colors.white60)),
      ]),
    );
  }

  Widget _buildForm() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        Text('${_lang.tr("task_title")} : ${widget.taskTitle}',
            style: const TextStyle(color: Colors.white70, fontSize: 16)),
        const SizedBox(height: 30),
        GestureDetector(
          onTap: () => _pickImage(ImageSource.gallery),
          child: Container(
            width: double.infinity,
            height: 220,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white24),
            ),
            child: _proofImage != null
                ? ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(_proofImage!, fit: BoxFit.cover))
                : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.add_a_photo, color: Colors.white38, size: 50),
              const SizedBox(height: 12),
              Text(_lang.tr('add_photo'), style: const TextStyle(color: Colors.white38)),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => _pickImage(ImageSource.camera),
          icon: const Icon(Icons.camera_alt, color: Colors.white70),
          label: Text(_lang.tr('take_photo'), style: const TextStyle(color: Colors.white70)),
          style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white24)),
        ),
        const SizedBox(height: 30),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _submitProof,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0A0F2C),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(_lang.tr('validate_proof'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ]),
    );
  }
}