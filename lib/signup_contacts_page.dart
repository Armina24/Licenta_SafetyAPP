import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SignupContactsPage extends StatefulWidget {
  const SignupContactsPage({super.key});

  @override
  State<SignupContactsPage> createState() => _SignupContactsPageState();
}

class _SignupContactsPageState extends State<SignupContactsPage> {
  final _contact1NameController = TextEditingController();
  final _contact1PhoneController = TextEditingController();
  final _contact2NameController = TextEditingController();
  final _contact2PhoneController = TextEditingController();

  Map<String, dynamic>? _signupArgs;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _signupArgs ??=
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
  }

  @override
  void dispose() {
    _contact1NameController.dispose();
    _contact1PhoneController.dispose();
    _contact2NameController.dispose();
    _contact2PhoneController.dispose();
    super.dispose();
  }

  void _skipOrContinue() {
    _saveContactsAndContinue();
  }

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFFF8C42);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF8F2),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1F1F1F)),
        title: const Text(
          'Sign up – Emergency contacts',
          style: TextStyle(color: Color(0xFF1F1F1F)),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _skipOrContinue,
            child: const Text('Skip', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choose 1–2 trusted contacts.\n'
                'We will notify them if you trigger an alert.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),

              const Text(
                'Contact 1',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _contact1NameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _contact1PhoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                ),
              ),

              const SizedBox(height: 20),
              const Text(
                'Contact 2 (optional)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _contact2NameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _contact2PhoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                ),
              ),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _skipOrContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension on _SignupContactsPageState {
  Future<void> _saveContactsAndContinue() async {
    final email = _signupArgs?['email'] as String?;
    if (email == null || email.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Repornește procesul de înregistrare.')),
        );
      }
      Navigator.popUntil(context, ModalRoute.withName('/signup'));
      return;
    }

    final contacts = <Map<String, String>>[];

    if (_contact1NameController.text.trim().isNotEmpty &&
        _contact1PhoneController.text.trim().isNotEmpty) {
      contacts.add({
        'name': _contact1NameController.text.trim(),
        'phone': _contact1PhoneController.text.trim(),
      });
    }

    if (_contact2NameController.text.trim().isNotEmpty &&
        _contact2PhoneController.text.trim().isNotEmpty) {
      contacts.add({
        'name': _contact2NameController.text.trim(),
        'phone': _contact2PhoneController.text.trim(),
      });
    }

    final prefs = await SharedPreferences.getInstance();

    if (contacts.isNotEmpty) {
      final contactsJson = contacts
          .map((c) => '${c['name']}::${c['phone']}')
          .join('|');
      await prefs.setString('emergency_contacts_list', contactsJson);
    }

    final phones = contacts.map((c) => c['phone']!).toList();
    await prefs.setString('emergency_contacts', phones.join(','));

    if (!mounted) return;
    final args = Map<String, dynamic>.from(_signupArgs ?? {});
    args['contacts'] = phones;
    Navigator.pushNamed(context, '/signupLocation', arguments: args);
  }
}
