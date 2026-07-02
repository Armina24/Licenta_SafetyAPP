import 'package:flutter/material.dart';
import 'services/alerts_service.dart';
import 'config/app_theme.dart';
import 'ui/scaffold_wrapper.dart';

class AlertsHistoryPage extends StatefulWidget {
  const AlertsHistoryPage({super.key});

  @override
  State<AlertsHistoryPage> createState() => _AlertsHistoryPageState();
}

class _AlertsHistoryPageState extends State<AlertsHistoryPage> {
  static const Color _bgColor = Color(0xFFFFF8F2);
  static const Color _orange = Color(0xFFFF8C42);

  late Future<List<Map<String, dynamic>>> _alertsFuture;

  @override
  void initState() {
    super.initState();
    _alertsFuture = AlertsService.instance.fetchAlerts();
  }

  String _formatDateTime(dynamic timestamp) {
    try {
      if (timestamp is String) {
        final dt = DateTime.parse(timestamp);
        return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
      }
    } catch (_) {}
    return 'N/A';
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'sent':
        return Colors.green;
      case 'failed':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
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
      title: Text('Alerts History', style: TextStyle(color: titleColor)),
      centerTitle: true,
    );

    final body = SafeArea(
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _alertsFuture,
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
                    'Failed to load alerts',
                    style: TextStyle(color: secondaryText),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _alertsFuture = AlertsService.instance.fetchAlerts();
                      });
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: _orange),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final alerts = snapshot.data ?? [];

          if (alerts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history,
                    size: 64,
                    color: isDarkMode
                        ? AppTheme.textTertiary.withValues(alpha: 0.5)
                        : Colors.grey.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No alerts history',
                    style: TextStyle(fontSize: 18, color: secondaryText),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your SOS alerts will appear here',
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
            itemCount: alerts.length,
            itemBuilder: (context, index) {
              final alert = alerts[index];
              final status = alert['status'] as String?;
              final timestamp = alert['timestamp'] as String?;
              final message = alert['message'] as String?;
              final contactsReached = alert['contactsReached'] as int?;

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
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: _getStatusColor(status),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'SOS Alert • ${status?.toUpperCase() ?? 'UNKNOWN'}',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: titleColor,
                              ),
                            ),
                          ),
                          Text(
                            _formatDateTime(timestamp),
                            style: TextStyle(
                              fontSize: 12,
                              color: secondaryText,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (message != null && message.isNotEmpty)
                        Text(
                          message,
                          style: TextStyle(fontSize: 13, color: secondaryText),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (contactsReached != null && contactsReached > 0) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.contacts_outlined,
                              size: 16,
                              color: _orange,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Reached $contactsReached contact(s)',
                              style: TextStyle(fontSize: 12, color: _orange),
                            ),
                          ],
                        ),
                      ],
                    ],
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
