import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';

/// /auth — phone OTP (mock 123456) + role select + PDPA consent.
class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final TextEditingController _phone = TextEditingController(text: '0812345678');
  final TextEditingController _otp = TextEditingController();
  bool _otpSent = false;
  bool _consent = false;
  UserRole _role = UserRole.farmer;

  @override
  void dispose() {
    _phone.dispose();
    _otp.dispose();
    super.dispose();
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
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: state.tr('phone'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          if (!_otpSent)
            FilledButton(
              onPressed: () {
                if (state.sendMockOtp(_phone.text)) {
                  setState(() => _otpSent = true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('OTP (mock): 123456')),
                  );
                }
              },
              child: const Text('ขอ OTP / Send OTP'),
            ),
          if (_otpSent) ...[
            TextField(
              controller: _otp,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: state.tr('otp'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
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
            FilledButton(
              onPressed: (!_consent ||
                      !state.verifyMockOtp(_otp.text.trim()))
                  ? null
                  : () {
                      state.signIn(phone: _phone.text.trim(), role: _role);
                      context.go(_role == UserRole.farmer
                          ? '/farmer/home'
                          : _role == UserRole.corporate
                              ? '/corporate'
                              : '/shop');
                    },
              child: Text(state.tr('login')),
            ),
          ],
        ],
      ),
    );
  }
}
