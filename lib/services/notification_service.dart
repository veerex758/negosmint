import 'supabase_client.dart';
import '../models/app_notification.dart';

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  Future<List<AppNotification>> fetchNotifications(String userId) async {
    final rows = await supabase
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => AppNotification.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> markRead(String notificationId) {
    return supabase
        .from('notifications')
        .update({'read': true})
        .eq('id', notificationId);
  }

  Future<int> unreadCount(String userId) async {
    final rows = await supabase
        .from('notifications')
        .select('id')
        .eq('user_id', userId)
        .eq('read', false);
    return (rows as List).length;
  }
}
