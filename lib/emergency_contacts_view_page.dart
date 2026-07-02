import 'package:flutter/material.dart';
import 'services/emergency_contacts_service.dart';
import 'config/app_theme.dart';
import 'ui/scaffold_wrapper.dart';

class EmergencyContactsViewPage extends StatefulWidget {
  const EmergencyContactsViewPage({super.key});

  @override
  State<EmergencyContactsViewPage> createState() =>
      _EmergencyContactsViewPageState();
}

class _EmergencyContactsViewPageState extends State<EmergencyContactsViewPage> {
  static const Color _bgColor = Color(0xFFFFF8F2);
  static const Color _orange = Color(0xFFFF8C42);

  late Future<List<Map<String, dynamic>>> _contactsFuture;

  @override
  void initState() {
    super.initState();
    _contactsFuture = EmergencyContactsService.instance.fetchContacts();
  }

  Future<void> _deleteContact(int contactId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Contact'),
        content: const Text('Are you sure you want to delete this contact?'),
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
      try {
        await EmergencyContactsService.instance.deleteContact(contactId);
        if (!mounted) return;

        setState(() {
          _contactsFuture = EmergencyContactsService.instance.fetchContacts();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contact deleted'),
            duration: Duration(seconds: 2),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
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

    final appBar = AppBar(
      backgroundColor: isDarkMode ? Colors.transparent : _bgColor,
      elevation: 0,
      iconTheme: IconThemeData(color: titleColor),
      title: Text(
        'Emergency Contacts (Server)',
        style: TextStyle(color: titleColor),
      ),
      centerTitle: true,
    );

    final body = SafeArea(
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _contactsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load contacts',
                    style: TextStyle(color: secondaryText),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _contactsFuture = EmergencyContactsService.instance
                            .fetchContacts();
                      });
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: _orange),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final contacts = snapshot.data ?? [];

          if (contacts.isEmpty) {
            return Center(
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
                    'Add contacts from the Emergency Contacts page',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode
                          ? AppTheme.textTertiary
                          : Colors.grey.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: contacts.length,
            itemBuilder: (context, index) {
              final contact = contacts[index];
              final name = contact['name'] as String?;
              final phoneNumber = contact['phoneNumber'] as String?;
              final relationship = contact['relationship'] as String?;
              final id = contact['id'] as int?;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
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
                      name?[0].toUpperCase() ?? '?',
                      style: const TextStyle(
                        color: AppTheme.accentOrange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    name ?? 'Unknown',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                      color: titleColor,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        phoneNumber ?? 'N/A',
                        style: TextStyle(fontSize: 14, color: secondaryText),
                      ),
                      if (relationship != null && relationship.isNotEmpty)
                        Text(
                          relationship,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDarkMode
                                ? AppTheme.textTertiary
                                : Colors.grey.withValues(alpha: 0.6),
                          ),
                        ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                    ),
                    onPressed: id != null ? () => _deleteContact(id) : null,
                    tooltip: 'Delete',
                  ),
                ),
              );
            },
          );
        },
      ),
    );

    if (isDarkMode) {
      return ScaffoldWrapper(appBar: appBar, body: body);
    }

    return Scaffold(backgroundColor: bgColor, appBar: appBar, body: body);
  }
}
