import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/theme/app_colors.dart';
import '../../models/app_notification_model.dart';
import '../../services/notification_service.dart';
import '../../widgets/found_it_loading_indicator.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notificationService = NotificationService();
  Stream<List<AppNotificationModel>>? _notificationsStream;
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};
  List<AppNotificationModel> _currentNotifications = [];

  @override
  void initState() {
    super.initState();
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      _notificationsStream = _notificationService.getUserNotificationsStream(userId);
    }
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      _selectedIds.clear();
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedIds.length == _currentNotifications.length) {
        _selectedIds.clear();
        _isSelectionMode = false;
      } else {
        _selectedIds.addAll(_currentNotifications.map((n) => n.id));
      }
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    await _notificationService.deleteNotifications(_selectedIds.toList());
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
  }

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

  Color _colorForType(String type, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (type) {
      case 'report_approved':
        return isDark ? Colors.green.shade300 : Colors.green.shade600;
      case 'nearby_report':
        return isDark ? Colors.blue.shade300 : Colors.blue.shade600;
      case 'report_found':
        return isDark ? Colors.orange.shade300 : Colors.orange.shade600;
      case 'report_reserved':
        return isDark ? Colors.purple.shade300 : Colors.purple.shade600;
      case 'lost_report_resolved':
        return isDark ? Colors.teal.shade300 : Colors.teal.shade600;
      case 'post_deleted':
        return isDark ? Colors.red.shade300 : Colors.red.shade600;
      case 'new_message':
        return isDark ? Colors.blue.shade300 : Colors.blue.shade600;
      default:
        return isDark ? Colors.deepPurple.shade300 : AppColors.deepLavender;
    }
  }

  Widget _buildNotificationTile(
    BuildContext context,
    AppNotificationModel notification,
  ) {
    final color = _colorForType(notification.type, context);
    final isSelected = _selectedIds.contains(notification.id);

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            width: _isSelectionMode ? 44.0 : 0.0,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              child: SizedBox(
                width: 44.0,
                child: Checkbox(
                  value: isSelected,
                  onChanged: (value) {
                    _toggleSelection(notification.id);
                  },
                  activeColor: Colors.blue,
                ),
              ),
            ),
          ),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                color: notification.isRead
                    ? Theme.of(context).cardColor
                    : Theme.of(context).colorScheme.primaryContainer.withOpacity(0.18),
                borderRadius: BorderRadius.circular(16),
                border: isSelected
                    ? Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 1.5,
                      )
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ListTile(
                onLongPress: () {
                  if (!_isSelectionMode) {
                    setState(() {
                      _isSelectionMode = true;
                      _selectedIds.add(notification.id);
                    });
                  }
                },
                onTap: () async {
                  if (_isSelectionMode) {
                    _toggleSelection(notification.id);
                  } else {
                    if (!notification.isRead) {
                      await _notificationService.markAsRead(notification.id);
                    }
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
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: _isSelectionMode
            ? Text('${_selectedIds.length} Selected')
            : const Text('Notifications'),
        backgroundColor: AppColors.deepLavender,
        foregroundColor: Colors.white,
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _toggleSelectionMode,
              )
            : null,
        actions: _isSelectionMode
            ? [
                IconButton(
                  icon: const Icon(PhosphorIconsRegular.checkSquareOffset),
                  onPressed: _selectAll,
                  tooltip: 'Select All',
                ),
                IconButton(
                  icon: const Icon(PhosphorIconsRegular.trash),
                  onPressed: _deleteSelected,
                  tooltip: 'Delete',
                ),
              ]
            : [
                if (userId != null)
                  TextButton(
                    onPressed: () async {
                      await _notificationService.markAllAsRead(userId);
                    },
                    child: const Text(
                      'Mark all read',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
              ],
      ),
      body: userId == null || _notificationsStream == null
          ? const Center(child: Text('Please log in to see notifications'))
          : StreamBuilder<List<AppNotificationModel>>(
              stream: _notificationsStream,
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
                
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _currentNotifications = notifications;
                  }
                });

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
                    );
                  },
                );
              },
            ),
    );
  }
}
