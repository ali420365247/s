import 'package:flutter/material.dart';
import 'identity_manager.dart';

class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key});

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  final _controller = TextEditingController();
  Map<String, dynamic> _contacts = {};
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final c = await IdentityManager.getContacts();
    if (mounted) setState(() { _contacts = c; _loading = false; });
  }

  Future<void> _sendRequest() async {
    final id = _controller.text.trim();
    if (id.isEmpty) return;
    setState(() => _loading = true);
    await IdentityManager.sendContactRequest(id, displayName: id);
    _controller.clear();
    await _load();
  }

  Widget _buildRow(String id, Map<String, dynamic> entry) {
    final status = entry['status'] as String? ?? 'pending';
    final name = entry['name'] as String? ?? id;
    return ListTile(
      title: Text(name),
      subtitle: Text('ID: $id — $status'),
      trailing: status == 'pending'
          ? Row(mainAxisSize: MainAxisSize.min, children: [
              TextButton(onPressed: () async { await IdentityManager.acceptContactRequest(id); await _load(); }, child: const Text('Accept')),
              TextButton(onPressed: () async { await IdentityManager.rejectContactRequest(id); await _load(); }, child: const Text('Reject')),
            ])
          : Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.check, color: Colors.green),
              const SizedBox(width: 8),
              TextButton(onPressed: () async {
                // start export to this accepted contact
                final ok = await OfflineTransferService.startExportTo(id);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Transfer started' : 'Transfer blocked')));
              }, child: const Text('Transfer')),
            ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contacts & Requests')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(children: [
              Expanded(child: TextField(controller: _controller, decoration: const InputDecoration(hintText: 'Enter Index ID'))),
              const SizedBox(width: 8),
              ElevatedButton(onPressed: _loading ? null : _sendRequest, child: const Text('Send')),
            ],),
            const SizedBox(height: 12),
            Expanded(child: _loading ? const Center(child: CircularProgressIndicator()) : ListView(
              children: _contacts.keys.map((k) => _buildRow(k, Map<String,dynamic>.from(_contacts[k] ?? {}))).toList(),
            )),
          ],
        ),
      ),
    );
  }
}
