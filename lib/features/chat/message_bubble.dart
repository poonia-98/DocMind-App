
import 'package:flutter/material.dart';
import '../../shared/theme/app_colors.dart';

class MessageBubble extends StatelessWidget {
  final String text;
  final bool isUser;
  final String timestamp;
  final bool isError;

  const MessageBubble({
    super.key,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: isError
                  ? Colors.red.withOpacity(0.2)
                  : (isDark ? AppColors.primaryDark : AppColors.primary)
                      .withOpacity(0.2),
              child: Icon(
                isError ? Icons.error_outline : Icons.smart_toy,
                size: 16,
                color: isError
                    ? Colors.red
                    : (isDark ? AppColors.primaryDark : AppColors.primary),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isError
                    ? Colors.red.withOpacity(0.1)
                    : isUser
                        ? (isDark
                            ? AppColors.messageBubbleUserDark
                            : AppColors.messageBubbleUser)
                        : (isDark
                            ? AppColors.messageBubbleSystemDark
                            : AppColors.messageBubbleSystem),
                borderRadius: BorderRadius.circular(12),
                border: isError
                    ? Border.all(color: Colors.red.withOpacity(0.3))
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: TextStyle(
                      color: isError
                          ? Colors.red
                          : isUser
                              ? (isDark
                                  ? AppColors.textPrimaryDark
                                  : Colors.white)
                              : (isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimary),
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTimestamp(timestamp),
                    style: TextStyle(
                      color: isError
                          ? Colors.red.withOpacity(0.7)
                          : isUser
                              ? (isDark
                                  ? AppColors.textSecondaryDark.withOpacity(0.7)
                                  : Colors.white70)
                              : (isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondary),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor:
                  (isDark ? AppColors.primaryDark : AppColors.primary)
                      .withOpacity(0.2),
              child: Icon(
                Icons.person,
                size: 16,
                color: isDark ? AppColors.primaryDark : AppColors.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTimestamp(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inHours < 1) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inDays < 1) {
        return '${difference.inHours}h ago';
      } else {
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      }
    } catch (e) {
      return 'Now';
    }
  }
}
