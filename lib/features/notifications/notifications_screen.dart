import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
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
  ) {
    final color = _colorForType(notification.type);
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
                color: notification.isRead ? Colors.white : const Color(0xFFF4F7FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected 
                      ? Colors.blue
                      : (notification.isRead
                          ? const Color(0xFFEDEDF3)
                          : const Color(0xFFD9E5FF)),
                ),
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
                        decoration: const BoxDecoration(
                          color: Colors.blue,
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
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: _isSelectionMode
            ? Text('${_selectedIds.length} Selected')
            : const Text('Notifications'),
        backgroundColor: AppColors.nightfall,
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
