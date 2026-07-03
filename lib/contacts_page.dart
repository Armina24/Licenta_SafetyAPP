import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ui/scaffold_wrapper.dart';
import 'config/app_theme.dart';
import 'services/emergency_contacts_service.dart';
import 'services/user_profile_storage.dart';

class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key});

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  static const Color _bgColor = Color(0xFFFFF8F2);
  static const Color _orange = Color(0xFFFF8C42);

  List<Map<String, String>> _contacts = [];
  final EmergencyContactsService _contactsService =
      EmergencyContactsService.instance;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final prefs = await SharedPreferences.getInstance();

    String? contactsJson = UserProfileStorage.getString(
      prefs,
      'emergency_contacts_list',
    );

    if (contactsJson == null) {
      final legacyJson = prefs.getString('emergency_contacts_list');
      if (legacyJson != null && legacyJson.isNotEmpty) {
        contactsJson = legacyJson;

        await UserProfileStorage.setString(
          prefs,
          'emergency_contacts_list',
          legacyJson,
        );
      }
    }

    if (contactsJson != null && contactsJson.isNotEmpty) {
      final List<dynamic> parsed = contactsJson
          .split('|')
          .map((item) {
            final parts = item.split('::');
            if (parts.length == 2) {
              return {'name': parts[0], 'phone': parts[1]};
            }
            return null;
          })
          .where((item) => item != null)
          .toList();

      setState(() {
        _contacts = List<Map<String, String>>.from(parsed);
      });
    } else {
      final csv = prefs.getString('emergency_contacts') ?? '';
      final phones = csv
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      if (phones.isNotEmpty) {
        final contacts = phones
            .map((phone) => {'name': 'Contact', 'phone': phone})
            .toList();
        setState(() {
          _contacts = List<Map<String, String>>.from(contacts);
        });

        final promoted = contacts
            .map((c) => '${c['name']}::${c['phone']}')
            .join('|');
        await UserProfileStorage.setString(
          prefs,
          'emergency_contacts_list',
          promoted,
        );
      } else {
        setState(() {
          _contacts = [];
        });
      }
    }
  }

  Future<void> _saveContacts() async {
    final prefs = await SharedPreferences.getInstance();

    final contactsJson = _contacts
        .map((c) => '${c['name']}::${c['phone']}')
        .join('|');

    await UserProfileStorage.setString(
      prefs,
      'emergency_contacts_list',
      contactsJson,
    );

    final phones = _contacts.map((c) => c['phone']!).join(',');
    await prefs.setString('emergency_contacts', phones);

    _syncContactsToServer();
  }

  Future<void> _syncContactsToServer() async {
    try {
      final serverContacts = await _contactsService.fetchContacts();

      for (final contact in _contacts) {
        final exists = serverContacts.any(
          (sc) => sc['phoneNumber'] == contact['phone'],
        );

        if (!exists) {
          await _contactsService.addContact(
            name: contact['name'] ?? 'Contact',
            phoneNumber: contact['phone'] ?? '',
          );
        }
      }

      debugPrint('Contactele au fost sincronizate cu serverul');
    } catch (e) {
      debugPrint('Eroare la sincronizarea contactelor: $e');
    }
  }

  Future<void> _addContact() async {
    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(builder: (context) => const AddContactPage()),
    );

    if (result != null) {
      setState(() {
        _contacts.add(result);
      });
      await _saveContacts();
    }
  }

  Future<void> _editContact(int index) async {
    final contact = _contacts[index];
    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (context) => AddContactPage(
          initialName: contact['name'],
          initialPhone: contact['phone'],
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _contacts[index] = result;
      });
      await _saveContacts();
    }
  }

  Future<void> _deleteContact(int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Contact'),
        content: Text(
          'Are you sure you want to delete ${_contacts[index]['name']}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _contacts.removeAt(index);
      });
      await _saveContacts();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDarkMode ? Colors.transparent : _bgColor;
    final titleColor = isDarkMode
        ? AppTheme.textPrimary
        : const Color(0xFF1F1F1F);
    final secondaryText = isDarkMode
        ? AppTheme.textSecondary
        : Colors.grey.withValues(alpha: 0.7);
    final subtleText = isDarkMode
        ? AppTheme.textTertiary
        : Colors.grey.withValues(alpha: 0.6);

    final appBar = AppBar(
      backgroundColor: isDarkMode ? Colors.transparent : _bgColor,
      elevation: 0,
      iconTheme: IconThemeData(color: titleColor),
      title: Text('Emergency Contacts', style: TextStyle(color: titleColor)),
      centerTitle: true,
    );

    final body = SafeArea(
      child: _contacts.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.contacts_outlined,
                    size: 64,
                    color: isDarkMode
                        ? AppTheme.textTertiary.withValues(alpha: 0.5)
                        : Colors.grey.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No emergency contacts',
                    style: TextStyle(fontSize: 18, color: secondaryText),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add trusted contacts to receive\nSOS alerts',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: subtleText),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _contacts.length,
              itemBuilder: (context, index) {
                final contact = _contacts[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isDarkMode
                          ? AppTheme.glassBorder
                          : Colors.grey.withValues(alpha: 0.1),
                    ),
                  ),
                  color: isDarkMode ? AppTheme.glassDarkMedium : Colors.white,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.accentOrange.withValues(
                        alpha: 0.2,
                      ),
                      child: Text(
                        contact['name']![0].toUpperCase(),
                        style: const TextStyle(
                          color: AppTheme.accentOrange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      contact['name']!,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                        color: titleColor,
                      ),
                    ),
                    subtitle: Text(
                      contact['phone']!,
                      style: TextStyle(fontSize: 14, color: secondaryText),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.edit_outlined,
                            color: isDarkMode
                                ? AppTheme.accentBlue
                                : Colors.grey.withValues(alpha: 0.7),
                          ),
                          onPressed: () => _editContact(index),
                          tooltip: 'Edit',
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                          ),
                          onPressed: () => _deleteContact(index),
                          tooltip: 'Delete',
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );

    if (isDarkMode) {
      return ScaffoldWrapper(
        appBar: appBar,
        body: body,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _addContact,
          backgroundColor: AppTheme.accentOrange,
          icon: const Icon(Icons.add),
          label: const Text('Add Contact'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: appBar,
      body: body,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addContact,
        backgroundColor: _orange,
        icon: const Icon(Icons.add),
        label: const Text('Add Contact'),
      ),
    );
  }
}

class AddContactPage extends StatefulWidget {
  final String? initialName;
  final String? initialPhone;

  const AddContactPage({super.key, this.initialName, this.initialPhone});

  @override
  State<AddContactPage> createState() => _AddContactPageState();
}

class _AddContactPageState extends State<AddContactPage> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  static const Color _orange = Color(0xFFFF8C42);

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.initialName ?? '';
    _phoneController.text = widget.initialPhone ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      Navigator.pop(context, {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialName != null;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF8F2),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1F1F1F)),
        title: Text(
          isEditing ? 'Edit Contact' : 'Add Contact',
          style: const TextStyle(color: Color(0xFF1F1F1F)),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Contact Information',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    hintText: 'Enter contact name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    hintText: 'Enter phone number',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    prefixIcon: const Icon(Icons.phone_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a phone number';
                    }

                    final phone = value.trim().replaceAll(
                      RegExp(r'[^\d+]'),
                      '',
                    );
                    if (phone.length < 8) {
                      return 'Please enter a valid phone number';
                    }
                    return null;
                  },
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: Text(isEditing ? 'Save Changes' : 'Add Contact'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
