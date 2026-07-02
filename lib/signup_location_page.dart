import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/auth_service.dart';
import 'services/user_profile_storage.dart';
import 'services/profile_service.dart';
import 'services/emergency_contacts_service.dart';

class SignupLocationPage extends StatefulWidget {
  const SignupLocationPage({super.key});

  @override
  State<SignupLocationPage> createState() => _SignupLocationPageState();
}

class _SignupLocationPageState extends State<SignupLocationPage> {
  bool _isFinishing = false;
  Map<String, dynamic>? _signupArgs;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _signupArgs ??=
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
  }

  Future<void> _finishSignup() async {
    final email = _signupArgs?['email'] as String?;
    final password = _signupArgs?['password'] as String?;

    if (email == null || password == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Date incomplete. Repornește înscrierea.'),
        ),
      );
      Navigator.popUntil(context, ModalRoute.withName('/signup'));
      return;
    }

    setState(() => _isFinishing = true);

    try {
      await AuthService.instance.register(email: email, password: password);
    } on AuthException catch (err) {
      if (mounted) {
        setState(() => _isFinishing = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(err.message)));
        if (err.statusCode == 409) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      }
      return;
    } catch (e, stackTrace) {
      debugPrint("Eroare la înregistrare: $e");
      debugPrint("Stack trace: $stackTrace");
      if (mounted) {
        setState(() => _isFinishing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nu s-a putut crea contul. Încearcă din nou.'),
          ),
        );
      }
      return;
    }

    try {
      await AuthService.instance.login(email: email, password: password);

      final prefs = await SharedPreferences.getInstance();
      final legacyJson = prefs.getString('emergency_contacts_list');
      if (legacyJson != null && legacyJson.isNotEmpty) {
        await UserProfileStorage.setString(
          prefs,
          'emergency_contacts_list',
          legacyJson,
        );
      }

      final firstName = _signupArgs?['firstName'] as String? ?? '';
      final lastName = _signupArgs?['lastName'] as String? ?? '';
      final phone = _signupArgs?['phone'] as String? ?? '';
      final displayName = '$firstName $lastName'.trim();

      if (displayName.isNotEmpty || phone.isNotEmpty) {
        try {
          await ProfileService.instance.updateProfile(
            displayName: displayName.isNotEmpty ? displayName : null,
            phoneNumber: phone.isNotEmpty ? phone : null,
          );
        } catch (e) {
          debugPrint("Eroare la salvarea profilului pe server: $e");
        }
      }

      if (legacyJson != null && legacyJson.isNotEmpty) {
        try {
          final List<Map<String, String>> localContacts = legacyJson
              .split('|')
              .map((item) {
                final parts = item.split('::');
                if (parts.length == 2) {
                  return {'name': parts[0], 'phone': parts[1]};
                }
                return <String, String>{};
              })
              .where((map) => map.isNotEmpty)
              .toList();

          if (localContacts.isNotEmpty) {
            await EmergencyContactsService.instance.syncLocalContacts(
              localContacts,
            );
          }
        } catch (e) {
          debugPrint(
            "Eroare la sincronizarea contactelor de urgență pe server: $e",
          );
        }
      }
    } on AuthException catch (err) {
      if (mounted) {
        setState(() => _isFinishing = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(err.message)));
      }
      return;
    } catch (_) {
      if (mounted) {
        setState(() => _isFinishing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nu s-a putut face log in. Încearcă din nou.'),
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    setState(() => _isFinishing = false);

    Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
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
          'Sign up – Location',
          style: TextStyle(color: Color(0xFF1F1F1F)),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isFinishing ? null : _finishSignup,
            child: const Text('Skip', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'We use your location only when needed to keep you safe.\n\n'
                'It helps us send your real-time position to your trusted '
                'contacts when you trigger an alert.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 24),
              const Text(
                'You can always change this later in Settings.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isFinishing ? null : _finishSignup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: _isFinishing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Allow & Finish'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
