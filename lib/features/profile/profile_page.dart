import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../app.dart';
import '../../core/pdpa.dart';
import '../../core/photo.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';

/// /profile — edit display name + phone + avatar photo (protected).
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late TextEditingController _name;
  late TextEditingController _phone;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final AppUser? user = context.read<AppState>().currentUser;
    _name = TextEditingController(text: user?.displayName ?? '');
    _phone = TextEditingController(text: user?.phone ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _changeAvatar(AppState state) async {
    final Uint8List? bytes =
        await pickCompressedPhoto(ImageSource.gallery);
    if (bytes == null) return;
    final String objectName =
        'avatar-${state.currentUser!.id}.jpg';
    final String? path = await storePhoto(bytes,
        bucket: 'avatars', objectName: objectName);
    if (path == null) return;
    await state.updateProfile(
        avatarPath: path, avatarMemBytes: bytes);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('เปลี่ยนรูปโปรไฟล์แล้ว')));
    }
  }

  Future<void> _save(AppState state) async {
    setState(() => _saving = true);
    await state.updateProfile(
      displayName: _name.text.trim(),
      phone: _phone.text.trim(),
    );
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('บันทึกโปรไฟล์แล้ว')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = context.watch<AppState>();
    final AppUser? user = state.currentUser;
    if (user == null) {
      return const Scaffold(
          body: Center(child: Text('กรุณาเข้าสู่ระบบ')));
    }
    final Uint8List? memAvatar = state.avatarBytes[user.id];
    ImageProvider? avatar;
    if (memAvatar != null) {
      avatar = MemoryImage(memAvatar);
    } else if (user.avatarPath != null &&
        !user.avatarPath!.startsWith('memory:') &&
        !user.avatarPath!.startsWith('http') &&
        !kIsWeb) {
      avatar = FileImage(File(user.avatarPath!));
    } else if (user.avatarPath != null &&
        user.avatarPath!.startsWith('http')) {
      avatar = NetworkImage(user.avatarPath!);
    }

    return Scaffold(
      appBar: Got9Bar(title: 'โปรไฟล์ / Profile', showProfile: false),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 52,
                  backgroundImage: avatar,
                  child: avatar == null
                      ? Text(user.displayName.characters.firstOrNull ?? '?',
                          style: const TextStyle(fontSize: 40))
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: CircleAvatar(
                    radius: 18,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.camera_alt, size: 18),
                      onPressed: () => _changeAvatar(state),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Center(
              child: Text('${user.id} • ${_roleLabel(user.role)}',
                  style: Theme.of(context).textTheme.titleMedium)),
          Center(child: Text('เบอร์: ${maskPhone(user.phone)}')),
          Center(child: Text('KYC: ${user.kycStatus}')),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            decoration: const InputDecoration(
                labelText: 'ชื่อที่แสดง / Display name',
                border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
                labelText: 'เบอร์โทร / Phone',
                border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            title: Text(state.tr('consent'),
                style: Theme.of(context).textTheme.bodySmall),
            value: user.consentPdpa,
            onChanged: (v) =>
                state.updateProfile(consentPdpa: v ?? false),
          ),
          FilledButton(
            onPressed: _saving ? null : () => _save(state),
            child: _saving
                ? const CircularProgressIndicator()
                : Text(state.tr('save')),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () {
              state.signOut();
              context.go('/auth');
            },
            child: const Text('ออกจากระบบ / Sign out'),
          ),
        ],
      ),
    );
  }

  String _roleLabel(UserRole role) => switch (role) {
        UserRole.farmer => 'เกษตรกร (F-ID)',
        UserRole.buyer => 'ผู้ซื้อ (B-ID)',
        UserRole.corporate => 'องค์กร (C-ID)',
      };
}
