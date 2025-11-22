import 'dart:convert';
import 'package:flutter/material.dart';
import 'identity_manager.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _onLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final pwd = _passwordCtrl.text;
    try {
      final blob = await IdentityManager.login(pwd);
      if (blob != null) {
        if (!mounted) return;
        // Try to parse blob as utf8 JSON for user feedback
        String summary;
        try {
          final txt = utf8.decode(blob);
          summary = txt.length > 120 ? txt.substring(0, 120) + '...' : txt;
        } catch (_) {
          summary = 'Identity blob decrypted (${blob.length} bytes)';
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Login successful — $summary')));
        Navigator.of(context).pop();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Login failed: invalid credentials or biometric required')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Login error: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Login to your device account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
                validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
              ),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _loading ? null : _onLogin, child: _loading ? const CircularProgressIndicator() : const Text('Login')),
              const SizedBox(height: 8),
              const Text('Every 10th login will require a biometric second factor if available.'),
            ],
          ),
        ),
      ),
    );
  }
}
