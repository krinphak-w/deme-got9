import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';

// /auth — zero-cost mock login (LINE / Gmail, NO SMS OTP).
// SMS OTP costs money per message, so Phase 1 uses social mock login.
class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool _consent = false;
  UserRole _role = UserRole.farmer;

  void _login(AppState state, String via) {
    state.signInMock(role: _role, via: via);
    context.go(_role == UserRole.farmer
        ? '/farmer/home'
        : _role == UserRole.corporate
            ? '/corporate'
            : '/shop');
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = context.watch<AppState>();
    return Scaffold(
      appBar: Got9Bar(title: state.tr('appTitle')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              'assets/GOTech.jpg',
              height: 150,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 8),
          Text('GOT9 Phase 1 MVP',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          const Text('ปลูก-รับรอง-แปรรูป-เที่ยว ใน QR เดียว (ภูเรือ)',
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          Text(state.tr('role'),
              style: Theme.of(context).textTheme.titleMedium),
          RadioGroup<UserRole>(
            groupValue: _role,
            onChanged: (v) => setState(() => _role = v!),
            child: Column(
              children: [
                RadioListTile<UserRole>(
                  title: Text(state.tr('farmer')),
                  value: UserRole.farmer,
                ),
                RadioListTile<UserRole>(
                  title: Text(state.tr('buyer')),
                  value: UserRole.buyer,
                ),
                RadioListTile<UserRole>(
                  title: Text(state.tr('corporate')),
                  value: UserRole.corporate,
                ),
              ],
            ),
          ),
          CheckboxListTile(
            title: Text(state.tr('consent'),
                style: Theme.of(context).textTheme.bodySmall),
            value: _consent,
            onChanged: (v) => setState(() => _consent = v ?? false),
          ),
          const SizedBox(height: 4),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF06C755)),
            icon: const Text('LINE',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            label: const Text('Login with LINE (ฟรี ไม่มีค่า SMS)'),
            onPressed: !_consent ? null : () => _login(state, 'LINE-mock'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Text('G',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4285F4),
                    fontSize: 20)),
            label: const Text('Login with Gmail (ฟรี ไม่มีค่า SMS)'),
            onPressed: !_consent ? null : () => _login(state, 'Gmail-mock'),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.lightBlue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Free beta ใช้ LINE/Gmail Login แทน SMS OTP เพื่อประหยัดค่าส่ง SMS — ไม่เสียเงินสักบาท',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
