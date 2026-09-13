import 'supabase_client.dart';
import '../models/task_model.dart';

/// Reward-crediting always goes through `complete_task()` (see
/// supabase/schema.sql) — a SECURITY DEFINER Postgres function — rather
/// than this service writing to `transactions` itself. A user's own
/// client has no insert policy on that table, so there's no client-side
/// path to crediting an arbitrary reward.
class TaskService {
  TaskService._();
  static final instance = TaskService._();

  Future<List<TaskModel>> fetchTasks({String? category}) async {
    var query = supabase.from('tasks').select().eq('is_active', true);
    if (category != null && category != 'All') {
      query = query.eq('category', category);
    }
    final rows = await query.order('created_at', ascending: false);
    return (rows as List)
        .map((r) => TaskModel.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// Creates the task_submissions row that complete_task() will later
  /// look up. The `unique (task_id, user_id)` constraint on that table
  /// means a second call for the same task simply fails instead of
  /// letting someone start it twice.
  Future<String> startTask(String taskId) async {
    final row = await supabase
        .from('task_submissions')
        .insert({'task_id': taskId})
        .select()
        .single();
    return row['id'] as String;
  }

  Future<void> completeTask(String submissionId) {
    return supabase.rpc('complete_task', params: {
      'p_submission_id': submissionId,
    });
  }

  Future<int> fetchCompletedCount(String userId) async {
    final rows = await supabase
        .from('task_submissions')
        .select('id')
        .eq('user_id', userId)
        .eq('status', 'completed');
    return (rows as List).length;
  }
}
