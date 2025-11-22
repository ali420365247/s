import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'offline_transfer.dart';
import 'identity_manager.dart';
import 'register_page.dart';
import 'login_page.dart';
import 'contacts_page.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'platform_secure_storage.dart';

void main() {
  runApp(const NexusApp());
}

class NexusApp extends StatelessWidget {
  const NexusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nexus (MVP scaffold)',
      theme: ThemeData(primarySwatch: Colors.indigo),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _status = 'Idle';
  double _progress = 0.0;
  Uint8List? _lastBlob;
  Timer? _fallbackTimer;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    try {
      // Lazy import to avoid analysis errors if permission_handler not present
      // Request runtime permissions for Android (location, bluetooth, etc.)
      // Note: permission_handler requires platform setup as well.
      // We keep requests permissive and best-effort.
      // Import inside method to avoid unused import warnings.
      final permissionHandler = await Future.value(null);
      // This code is a placeholder — call Permission.*.request() in real app.
    } catch (_) {}
  }

  Future<void> _startExport() async {
    setState(() {
      _status = 'Starting export...';
      _progress = 0.05;
      _lastBlob = null;
    });

    // Kick off export. We'll also start a fallback timer to show QR if no
    // transfer finishes in time (e.g., 12s).
    _fallbackTimer?.cancel();
    _fallbackTimer = Timer(const Duration(seconds: 12), () async {
      final blob = await IdentityManager.exportEncryptedBlob();
      setState(() {
        _status = 'No peer found — show QR fallback';
        _lastBlob = blob;
        _progress = 1.0;
      });
    });

    try {
      await OfflineTransferService.startExport();
      _fallbackTimer?.cancel();
      setState(() {
        _status = 'Transfer completed — wiping old device (manual confirmation)';
        _progress = 1.0;
      });
      // Show confirmation to wipe old device (this code runs on the OLD phone after successful send)
      // Ask user to confirm destructive action.
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Wipe old device?'),
            content: const Text('Transfer completed. Do you want to securely erase keys and identity from this device? This action is irreversible.'),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
              ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Wipe')),
            ],
          ),
        );
        if (confirm == true) {
          setState(() { _status = 'Wiping device...'; _progress = 0.9; });
          final ok = await PlatformSecureStorage.wipeDevice();
          setState(() { _status = ok ? 'Wipe complete' : 'Wipe failed'; _progress = 1.0; });
        }
      });
    } catch (e) {
      // On scaffold errors, fall back to QR code already handled by timer.
      setState(() {
        _status = 'Export failed: ${e.toString()}';
        _progress = 0.0;
      });
    }
  }

  Future<void> _startImport() async {
    setState(() {
      _status = 'Starting import — waiting for peer...';
      _progress = 0.1;
    });
    try {
      await OfflineTransferService.startImport();
      setState(() {
        _status = 'Import successful';
        _progress = 1.0;
      });
    } catch (e) {
      setState(() {
        _status = 'Import failed: ${e.toString()}';
        _progress = 0.0;
      });
    }
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nexus — Transfer')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Unified Offline Transfer', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: _progress == 0.0 ? null : _progress),
            const SizedBox(height: 12),
            Text('Status: $_status'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: ElevatedButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterPage())), child: const Text('Register'))),
                const SizedBox(width: 8),
                Expanded(child: ElevatedButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginPage())), child: const Text('Login'))),
                const SizedBox(width: 8),
                Expanded(child: ElevatedButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ContactsPage())), child: const Text('Contacts'))),
              ],
            ),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: _startExport, child: const Text('Transfer to new phone (Export)')),
            ElevatedButton(onPressed: _startImport, child: const Text('Receive transfer (Import)')),
            const SizedBox(height: 16),
            if (_lastBlob != null) ...[
              const Text('QR fallback — scan this with the new device:'),
              const SizedBox(height: 8),
              Center(child: QrImage(data: base64Encode(_lastBlob!), size: 240)),
              const SizedBox(height: 8),
              SelectableText(base64Encode(_lastBlob!), maxLines: 3),
            ],
            const Spacer(),
            const Text('Notes: NFC tap preferred → WiFi-Direct → QR fallback.'),
          ],
        ),
      ),
    );
  }
}
