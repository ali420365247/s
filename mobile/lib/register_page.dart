import 'package:flutter/material.dart';
import 'identity_manager.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  DateTime? _birthDate;
  bool _loading = false;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _onRegister() async {
    if (!_formKey.currentState!.validate()) return;
    // Ensure birthdate selected and user is 18+
    if (_birthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select your birth date')));
      return;
    }
    final now = DateTime.now();
    var age = now.year - _birthDate!.year;
    if (now.month < _birthDate!.month || (now.month == _birthDate!.month && now.day < _birthDate!.day)) {
      age -= 1;
    }
    if (age < 18) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You must be 18 years or older to register')));
      return;
    }
    setState(() => _loading = true);
    final pwd = _passwordCtrl.text;
    try {
      final ok = await IdentityManager.registerAccount(pwd, birthDate: _birthDate);
      if (ok) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registration successful')));
        Navigator.of(context).pop();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registration failed: account may already exist')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Registration error: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Create your device account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () async {
                  final now = DateTime.now();
                  final initial = now.subtract(const Duration(days: 365 * 20));
                  final first = now.subtract(const Duration(days: 365 * 120));
                  final last = now.subtract(const Duration(days: 365 * 18));
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: initial,
                    firstDate: first,
                    lastDate: last,
                  );
                  if (picked != null) setState(() => _birthDate = picked);
                },
                child: Text(_birthDate == null ? 'Select birth date' : 'Birth date: ${_birthDate!.year}-${_birthDate!.month.toString().padLeft(2, '0')}-${_birthDate!.day.toString().padLeft(2, '0')}' ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
                validator: (v) => (v == null || v.length < 8) ? 'Password must be at least 8 characters' : null,
              ),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _loading ? null : _onRegister, child: _loading ? const CircularProgressIndicator() : const Text('Register')),
              const SizedBox(height: 8),
              const Text('This device supports a single account. If an account already exists, registration will fail.'),
            ],
          ),
        ),
      ),
    );
  }
}
