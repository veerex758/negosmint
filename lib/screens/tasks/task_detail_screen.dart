import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/particle_background.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/task_card.dart';
import '../../core/widgets/app_page_route.dart';
import '../../services/auth_service.dart';
import '../../services/task_service.dart';
import '../../models/task_model.dart';
import 'task_completion_screen.dart';

class TaskDetailScreen extends StatefulWidget {
  const TaskDetailScreen({super.key, required this.task});
  final TaskItem task;
  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  bool _working = false;
  TaskSubmission? _submission;
  final _proofController = TextEditingController();
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void dispose() {
    _timer?.cancel();
    _proofController.dispose();
    super.dispose();
  }

  void _startCountdown(DateTime until) {
    _timer?.cancel();
    void tick() {
      if (!mounted) return;
      setState(() => _remaining = until.difference(DateTime.now()));
    }
    tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  Future<void> _reserve() async {
    if (widget.task.id == null || !AuthService.instance.isSignedIn) return;
    setState(() => _working = true);
    try {
      final submission = await TaskService.instance.startTask(widget.task.id!);
      if (!mounted) return;
      setState(() {
        _submission = submission;
        _working = false;
      });
      if (submission.reservedUntil != null) {
        _startCountdown(submission.reservedUntil!);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _working = false);
        _show('Unable to reserve this task. It may be full, unavailable, or already started.');
      }
    }
  }

  Future<void> _submit() async {
    if (_submission == null || _proofController.text.trim().isEmpty) {
      _show('Add the required proof before submitting.');
      return;
    }
    if (_remaining.isNegative) {
      _show('This reservation has expired. Please reserve a new slot.');
      return;
    }

    setState(() => _working = true);
    try {
      final status = await TaskService.instance.submitProof(
        submissionId: _submission!.id,
        proofText: _proofController.text.trim(),
      );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        appRoute(
          TaskCompletionScreen(
            taskTitle: widget.task.title,
            reward: widget.task.reward,
            currencyCode: widget.task.currencyCode,
            instantApproved: status == 'completed',
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _working = false);
        _show('Proof could not be submitted. Check the reservation timer and try again.');
      }
    }
  }

  void _show(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final requirements = (task.requirements ?? 'Complete the task exactly as described.')
        .split(RegExp(r'[,\n]'))
        .where((r) => r.trim().isNotEmpty)
        .toList();
    final slots = task.totalSlots == null
        ? null
        : '${task.remainingSlots ?? 0} / ${task.totalSlots} slots left';
    final symbol = task.currencyCode == 'NGN' ? '₦' : r'$';

    return Scaffold(
      body: ParticleBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                    ),
                    const Text(
                      'Task details',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  children: [
                    GlassCard(
                      glowColor: AppColors.cobalt,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  gradient: AppColors.brandGradient,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.verified_outlined,
                                  color: AppColors.background,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      task.title,
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 17,
                                      ),
                                    ),
                                    Text(
                                      '${task.advertiserName ?? 'Verified advertiser'}${task.advertiserRating == null ? '' : ' · ★ ${task.advertiserRating!.toStringAsFixed(1)}'}',
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: _Stat(
                                  label: 'Reward',
                                  value: '$symbol${task.reward.toStringAsFixed(2)}',
                                  color: AppColors.highlight,
                                ),
                              ),
                              Expanded(
                                child: _Stat(
                                  label: 'Time',
                                  value: '${task.minutes} min',
                                ),
                              ),
                              Expanded(
                                child: _Stat(
                                  label: 'Verification',
                                  value: task.isInstantApprove ? 'Instant' : 'Review',
                                ),
                              ),
                            ],
                          ),
                          if (slots != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              slots,
                              style: const TextStyle(
                                color: AppColors.highlight,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 7),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: ((task.remainingSlots ?? 0) / task.totalSlots!).clamp(0.0, 1.0),
                                minHeight: 7,
                                color: AppColors.highlight,
                                backgroundColor: AppColors.surfaceElevated,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Requirements',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 9),
                    ...requirements.map(
                      (r) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.check_circle_outline,
                              size: 16,
                              color: AppColors.highlight,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                r.trim(),
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    GlassCard(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.shield_outlined, color: AppColors.warning),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Submit proof that directly satisfies the requirements. Instant tasks are checked against the campaign criteria; other submissions are reviewed before the reward is released.',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_submission != null) ...[
                      const SizedBox(height: 20),
                      GlassCard(
                        glowColor: AppColors.highlight,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Slot reserved · ${_remaining.isNegative ? 'Expired' : '${_remaining.inMinutes.remainder(60).toString().padLeft(2, '0')}:${_remaining.inSeconds.remainder(60).toString().padLeft(2, '0')}'}',
                              style: const TextStyle(
                                color: AppColors.highlight,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _proofController,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                hintText: 'Paste your required username, URL, or transaction ID',
                              ),
                            ),
                            const SizedBox(height: 12),
                            PrimaryButton(
                              label: 'Submit proof for verification',
                              loading: _working,
                              onPressed: _remaining.isNegative ? null : _submit,
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    if (_submission == null)
                      PrimaryButton(
                        label: 'Reserve slot for ${task.reservationMinutes} min',
                        loading: _working,
                        onPressed: _reserve,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color ?? AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
