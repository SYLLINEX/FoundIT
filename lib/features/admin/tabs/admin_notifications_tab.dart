import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../models/app_notification_model.dart';
import '../../../services/notification_service.dart';
import '../../../widgets/found_it_loading_indicator.dart';

class AdminNotificationsTab extends StatelessWidget {
  const AdminNotificationsTab({super.key});

  IconData _iconForType(String type) {
    if (type == 'admin_alert') return Icons.admin_panel_settings;
    if (type == 'report_approved') return Icons.verified;
    if (type == 'report_found') return Icons.search;
    if (type == 'report_reserved') return Icons.bookmark_added;
    return Icons.notifications;
  }

  @override
  Widget build(BuildContext context) {
    final adminId = FirebaseAuth.instance.currentUser?.uid;
    final service = NotificationService();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              const Text(
                'Admin Notifications',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (adminId != null)
                TextButton(
                  onPressed: () => service.markAllAsRead(adminId),
                  child: const Text('Mark all read'),
                ),
            ],
          ),
        ),
        Expanded(
          child: adminId == null
              ? const Center(child: Text('Not logged in as admin.'))
              : StreamBuilder<List<AppNotificationModel>>(
                  stream: service.getUserNotificationsStream(adminId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: FoundItLoadingIndicator());
                    }
                    final notifications = snapshot.data ?? [];
                    if (notifications.isEmpty) {
                      return const Center(
                        child: Text('No admin notifications yet.'),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: notifications.length,
                      itemBuilder: (context, index) {
                        final n = notifications[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            onTap: () async {
                              if (!n.isRead) {
                                await service.markAsRead(n.id);
                              }
                            },
                            leading: CircleAvatar(
                              backgroundColor: n.isRead
                                  ? Colors.grey.shade200
                                  : Colors.blue.shade100,
                              child: Icon(_iconForType(n.type)),
                            ),
                            title: Text(
                              n.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(n.body),
                            trailing: Text(
                              timeago.format(n.createdAt),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}
