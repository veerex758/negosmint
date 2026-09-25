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

  /// Reserves an inventory slot server-side. The database locks the task row
  /// and assigns an expiry, so a client cannot overbook a campaign.
  Future<TaskSubmission> startTask(String taskId) async {
    final row = await supabase.rpc('reserve_task_slot', params: {'p_task_id': taskId});
    return TaskSubmission.fromMap(row as Map<String, dynamic>);
  }

  /// Submits user-entered proof for the verification pipeline. Rewards are
  /// only credited by the server after automated or human verification.
  Future<String> submitProof({required String submissionId, String? proofText, String? proofImageUrl}) async {
    final status = await supabase.rpc('submit_task_proof', params: {
      'p_submission_id': submissionId,
      'p_proof_text': proofText,
      'p_proof_image_url': proofImageUrl,
    });
    return status as String;
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
