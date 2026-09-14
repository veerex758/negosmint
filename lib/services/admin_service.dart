import 'supabase_client.dart';
import '../models/admin_analytics.dart';
import '../models/admin_withdrawal.dart';
import '../models/admin_user_row.dart';
import '../models/admin_growth_point.dart';
import '../models/task_model.dart';

/// Every method here is only meaningful for an account with
/// `profiles.is_admin = true` — the underlying RLS policies and RPC
/// functions (see supabase/admin_migration.sql) enforce that server-side,
/// so this class doesn't need its own permission checks. A non-admin
/// calling these gets an empty result set or a "Not authorized" error
/// from Postgres, never real data.
class AdminService {
  AdminService._();
  static final instance = AdminService._();

  Future<AdminAnalytics> fetchAnalytics() async {
    final rows = await supabase.rpc('admin_analytics');
    final list = rows as List;
    if (list.isEmpty) return AdminAnalytics.zero;
    return AdminAnalytics.fromMap(list.first as Map<String, dynamic>);
  }

  Future<List<AdminGrowthPoint>> fetchGrowthSeries() async {
    final rows = await supabase.rpc('admin_growth_series');
    return (rows as List)
        .map((r) => AdminGrowthPoint.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<List<AdminWithdrawal>> fetchWithdrawals({String? status}) async {
    var query = supabase.from('withdrawals').select('*, profiles(username)');
    if (status != null) query = query.eq('status', status);
    final rows = await query.order('created_at', ascending: false);
    return (rows as List)
        .map((r) => AdminWithdrawal.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> approveWithdrawal(String withdrawalId) {
    return supabase.rpc('approve_withdrawal', params: {
      'p_withdrawal_id': withdrawalId,
    });
  }

  Future<void> rejectWithdrawal(String withdrawalId) {
    return supabase.rpc('reject_withdrawal', params: {
      'p_withdrawal_id': withdrawalId,
    });
  }

  /// All tasks, including inactive ones — regular users only ever see
  /// `is_active = true` tasks (see the "Active tasks are visible to
  /// everyone" policy); this one relies on the separate admin-only
  /// select policy to see everything.
  Future<List<TaskModel>> fetchAllTasks() async {
    final rows =
        await supabase.from('tasks').select().order('created_at', ascending: false);
    return (rows as List)
        .map((r) => TaskModel.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> createTask({
    required String title,
    required String category,
    required double reward,
    required int minutes,
    String? description,
  }) {
    return supabase.from('tasks').insert({
      'title': title,
      'category': category,
      'reward': reward,
      'minutes': minutes,
      'description': description,
    });
  }

  Future<void> setTaskActive(String taskId, bool isActive) {
    return supabase
        .from('tasks')
        .update({'is_active': isActive}).eq('id', taskId);
  }

  Future<List<AdminUserRow>> fetchUsers() async {
    final rows =
        await supabase.from('profiles').select().order('created_at', ascending: false);
    return (rows as List)
        .map((r) => AdminUserRow.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> setUserSuspended(String userId, bool suspended) {
    return supabase
        .from('profiles')
        .update({'is_suspended': suspended}).eq('id', userId);
  }
}
