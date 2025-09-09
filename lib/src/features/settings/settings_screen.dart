import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _nameCtrl = TextEditingController();
  bool _saving = false;
  bool _uploading = false;

  User? get _user => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final user = _user;
    if (user == null) return;

    // Prefill mit Auth-Anzeigename
    _nameCtrl.text = user.displayName ?? '';

    // Wenn Firestore einen displayName hat, nimm den (Quelle der Wahrheit in deiner App)
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final fsName = snap.data()?['displayName'] as String?;
    if (fsName != null && fsName.trim().isNotEmpty) {
      _nameCtrl.text = fsName;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final user = _user;
    if (user == null) return;
    final name = _nameCtrl.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte gib einen Anzeigenamen ein.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      // Auth-Profil aktualisieren (optional, aber nice für FirebaseUI etc.)
      await user.updateDisplayName(name);

      // Firestore-User-Dokument aktualisieren
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {'displayName': name},
        SetOptions(merge: true),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Anzeigename gespeichert.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Speichern: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    final user = _user;
    if (user == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() => _uploading = true);
    try {
      final ref =
          FirebaseStorage.instance.ref().child('users/${user.uid}/avatar.jpg');

      // Web: kein dart:io File – stattdessen Bytes hochladen
      if (kIsWeb) {
        final Uint8List bytes = await picked.readAsBytes();
        await ref.putData(
          bytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
      } else {
        // iOS/Android: klassisch per File hochladen
        final file = File(picked.path);
        await ref.putFile(
          file,
          SettableMetadata(contentType: 'image/jpeg'),
        );
      }

      final url = await ref.getDownloadURL();

      // Auth-Profil & Firestore updaten
      await user.updatePhotoURL(url);
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {'photoURL': url},
        SetOptions(merge: true),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profilbild aktualisiert.')),
      );
      setState(() {}); // neu zeichnen
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload fehlgeschlagen: ${e.message}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload fehlgeschlagen: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _deleteAccount() async {
    final user = _user;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konto löschen?'),
        content: const Text(
          'Das kann nicht rückgängig gemacht werden. Alle deine Daten werden entfernt.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ja, löschen'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Optional: verbundene Daten in Firestore löschen. (Achtung: Kosten!)
      // Hier minimal nur das Auth-Konto löschen.
      await user.delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Konto gelöscht.')),
      );

      // Zurücknavigieren, oder zu Login
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      // Häufig: requires-recent-login -> Re-Login verlangen
      if (!mounted) return;
      final msg = e.code == 'requires-recent-login'
          ? 'Bitte melde dich neu an und versuche es erneut.'
          : 'Konnte Konto nicht löschen: ${e.message}';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Konnte Konto nicht löschen: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final photoURL = user?.photoURL;
    final nameInitial = (_nameCtrl.text.isNotEmpty
        ? _nameCtrl.text[0].toUpperCase()
        : (user?.email?.substring(0, 1).toUpperCase() ?? '?'));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Einstellungen'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Center(
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: const Color(0xFF1f2937),
                  backgroundImage: (photoURL != null && photoURL.isNotEmpty)
                      ? NetworkImage(photoURL)
                      : null,
                  child: (photoURL == null || photoURL.isEmpty)
                      ? Text(nameInitial,
                          style: const TextStyle(
                              fontSize: 36, fontWeight: FontWeight.bold))
                      : null,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: IconButton.filledTonal(
                    onPressed: _uploading ? null : _pickAndUploadPhoto,
                    icon: _uploading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.photo_camera),
                    tooltip: 'Profilbild ändern',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Anzeigename
          TextField(
            controller: _nameCtrl,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              labelText: 'Anzeigename',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _saving ? null : _saveName,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Speichern'),
          ),

          const SizedBox(height: 24),
          const Divider(height: 1),

          const SizedBox(height: 24),
          // Account Danger-Zone
          Text(
            'Konto',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            user?.email ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF9fb3c8)),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.delete_forever, color: Colors.red),
            label: const Text('Konto löschen',
                style: TextStyle(color: Colors.red)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red),
            ),
            onPressed: _deleteAccount,
          ),
        ],
      ),
    );
  }
}
