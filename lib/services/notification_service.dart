/// Placeholder for scheduled local notifications.
///
/// This intentionally does NOT touch the OS notification/alarm system yet -
/// by design, for now. Every place in the app that needs to show, update,
/// or cancel a reminder calls through here, so when the real
/// flutter_local_notifications + timezone wiring is added later, this is
/// the ONLY file that needs real implementation - nothing in the blocs,
/// repositories, or UI needs to change.
///
/// A task/document is only ever allowed to have its notifyEnabled flag set
/// to true once it has a real deadline (date+time for one-off tasks and
/// documents, or a daily reminder time for recurring tasks) - that rule is
/// enforced in the UI layer (DeadlineNotifyField), not here.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  /// Call when a task's notifyEnabled/deadline changes. [id] must be
  /// stable and unique across tasks and documents combined once real
  /// scheduling is added (e.g. prefix task ids vs document ids).
  Future<void> scheduleForTask({
    required int id,
    required String title,
    required DateTime? at,
    required bool enabled,
  }) async {
    // TODO: when flutter_local_notifications is added, schedule/cancel
    // the actual OS notification here based on `enabled` and `at`.
  }

  Future<void> scheduleForDocument({
    required int id,
    required String title,
    required DateTime? at,
    required bool enabled,
  }) async {
    // TODO: same as scheduleForTask, for documents.
  }

  Future<void> cancelForTask(int id) async {
    // TODO: cancel any pending OS notification for this task id.
  }

  Future<void> cancelForDocument(int id) async {
    // TODO: cancel any pending OS notification for this document id.
  }
}
