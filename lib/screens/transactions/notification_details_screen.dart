import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../services/notification_service.dart';

class NotificationDetailsScreen extends StatefulWidget {
  final NotificationItem notification;
  final NotificationService notificationService;

  const NotificationDetailsScreen({
    super.key,
    required this.notification,
    required this.notificationService,
  });

  @override
  State<NotificationDetailsScreen> createState() => _NotificationDetailsScreenState();
}

class _NotificationDetailsScreenState extends State<NotificationDetailsScreen>
    with SingleTickerProviderStateMixin {
  late NotificationItem _notification;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isMarking = false;

  @override
  void initState() {
    super.initState();
    _notification = widget.notification;
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
      ),
    );
    
    _animationController.forward();
    
    // Mark as read when viewing
    _markAsReadOnView();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _markAsReadOnView() async {
    if (!_notification.isRead) {
      setState(() => _isMarking = true);
      
      // Get the notification from API (which marks it as read)
      final updated = await widget.notificationService.getNotification(_notification.id);
      
      if (updated != null && mounted) {
        setState(() {
          _notification = updated;
          _isMarking = false;
        });
      } else {
        setState(() => _isMarking = false);
      }
    }
  }

  Future<void> _deleteNotification() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
            ),
            const SizedBox(width: 12),
            const Text('Delete Notification'),
          ],
        ),
        content: const Text(
          'Are you sure you want to delete this notification? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textColor.withOpacity(0.7)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final success = await widget.notificationService.deleteNotification(_notification.id);
      if (success && mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final sw = size.width;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: _getNotificationColor(_notification.type),
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _getNotificationColor(_notification.type),
        body: Column(
          children: [
            // Header Section
            SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(sw * 0.04, 16, sw * 0.04, 24),
                child: Column(
                  children: [
                    // App Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Back Button
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            onPressed: () => Navigator.pop(context, true),
                          ),
                        ),
                        const Text(
                          'Notification Details',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        // Delete Button
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            onPressed: _deleteNotification,
                            tooltip: 'Delete notification',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Icon and Status Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Icon
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _getNotificationIcon(_notification.type),
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Read Status Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isMarking)
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(Colors.white),
                                  ),
                                )
                              else
                                Icon(
                                  _notification.isRead
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              const SizedBox(width: 6),
                              Text(
                                _notification.isRead ? 'Read' : 'Unread',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Content Section
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(sw * 0.05, 30, sw * 0.05, 30),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title
                            Text(
                              _notification.title,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textColor,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Time Info
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  _buildInfoItem(
                                    icon: Icons.calendar_today_rounded,
                                    label: 'Date',
                                    value: _notification.formattedDate,
                                  ),
                                  Container(
                                    width: 1,
                                    height: 40,
                                    color: AppColors.lightGrey,
                                  ),
                                  _buildInfoItem(
                                    icon: Icons.access_time_rounded,
                                    label: 'Time',
                                    value: _notification.timeAgo,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            
                            // Message Section
                            _buildSectionHeader('Message'),
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Text(
                                _notification.message,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: AppColors.textColor.withOpacity(0.8),
                                  height: 1.7,
                                ),
                              ),
                            ),
                            
                            // Additional Data (if available)
                            if (_notification.data != null && _notification.data!.isNotEmpty) ...[
                              const SizedBox(height: 24),
                              _buildSectionHeader('Details'),
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.04),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: _notification.data!.entries.map((entry) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 12),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _formatKey(entry.key),
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: AppColors.textColor.withOpacity(0.5),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const Spacer(),
                                          Flexible(
                                            child: Text(
                                              entry.value.toString(),
                                              textAlign: TextAlign.right,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: _getNotificationColor(_notification.type),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textColor.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _getNotificationColor(_notification.type).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: _getNotificationColor(_notification.type),
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textColor.withOpacity(0.5),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatKey(String key) {
    // Convert snake_case to Title Case
    return key
        .split('_')
        .map((word) => word.isNotEmpty
            ? '${word[0].toUpperCase()}${word.substring(1)}'
            : '')
        .join(' ');
  }

  Color _getNotificationColor(String type) {
    switch (type.toLowerCase()) {
      case 'success':
      case 'credit':
        return AppColors.success;
      case 'warning':
        return AppColors.warning;
      case 'error':
      case 'failed':
        return AppColors.error;
      case 'transaction':
        return AppColors.accentTeal;
      case 'promo':
      case 'promotion':
        return AppColors.accentPink;
      case 'admin':
        return AppColors.primary;
      default:
        return AppColors.primary;
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type.toLowerCase()) {
      case 'success':
      case 'credit':
        return Icons.check_circle_rounded;
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'error':
      case 'failed':
        return Icons.error_rounded;
      case 'transaction':
        return Icons.swap_horiz_rounded;
      case 'promo':
      case 'promotion':
        return Icons.local_offer_rounded;
      case 'admin':
        return Icons.admin_panel_settings_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }
}
