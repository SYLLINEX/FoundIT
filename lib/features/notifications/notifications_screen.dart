import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/theme/app_colors.dart';
import '../../models/app_notification_model.dart';
import '../../services/notification_service.dart';
import '../../widgets/found_it_loading_indicator.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  IconData _iconForType(String type) {
    switch (type) {
      case 'report_approved':
        return PhosphorIconsRegular.sealCheck;
      case 'nearby_report':
        return PhosphorIconsRegular.paperPlaneTilt;
      case 'report_found':
        return PhosphorIconsRegular.magnifyingGlass;
      case 'report_reserved':
        return PhosphorIconsRegular.bookmarkSimple;
      case 'lost_report_resolved':
        return PhosphorIconsRegular.checkCircle;
      case 'post_deleted':
        return PhosphorIconsRegular.xCircle;
      case 'new_message':
        return PhosphorIconsRegular.chatCircleDots;
      default:
        return PhosphorIconsRegular.bell;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'report_approved':
        return Colors.green;
      case 'nearby_report':
        return Colors.blue;
      case 'report_found':
        return Colors.orange;
      case 'report_reserved':
        return Colors.purple;
      case 'lost_report_resolved':
        return Colors.teal;
      case 'post_deleted':
        return Colors.red;
      case 'new_message':
        return Colors.blue;
      default:
        return AppColors.deepLavender;
    }
  }

  Widget _buildNotificationTile(
    BuildContext context,
    AppNotificationModel notification,
    NotificationService service,
  ) {
    final color = _colorForType(notification.type);
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      decoration: BoxDecoration(
        color: notification.isRead ? Colors.white : const Color(0xFFF4F7FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: notification.isRead
              ? const Color(0xFFEDEDF3)
              : const Color(0xFFD9E5FF),
        ),
      ),
      child: ListTile(
        onTap: () async {
          if (!notification.isRead) {
            await service.markAsRead(notification.id);
          }
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 1),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.14),
          child: Icon(_iconForType(notification.type), color: color),
        ),
        title: Text(
          notification.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(notification.body),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              timeago.format(notification.createdAt),
              style: TextStyle(color: Colors.grey[600], fontSize: 11),
            ),
            if (!notification.isRead)
              Container(
                margin: const EdgeInsets.only(top: 6),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final notificationService = NotificationService();

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: AppColors.nightfall,
        foregroundColor: Colors.white,
        actions: [
          if (userId != null)
            TextButton(
              onPressed: () async {
                await notificationService.markAllAsRead(userId);
              },
              child: const Text(
                'Mark all read',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: userId == null
          ? const Center(child: Text('Please log in to see notifications'))
          : StreamBuilder<List<AppNotificationModel>>(
              stream: notificationService.getUserNotificationsStream(userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: FoundItLoadingIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Failed to load notifications: ${snapshot.error}',
                    ),
                  );
                }

                final notifications = snapshot.data ?? [];
                if (notifications.isEmpty) {
                  return const Center(
                    child: Text(
                      'No notifications yet.',
                      style: TextStyle(fontSize: 16),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    return _buildNotificationTile(
                      context,
                      notifications[index],
                      notificationService,
                    );
                  },
                );
              },
            ),
    );
  }
}
