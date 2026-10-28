/// The backend's verdict on a task photo.
class PhotoCheck {
  const PhotoCheck({
    required this.accepted,
    this.message = '',
    this.photosFulfilled,
    this.taskStatus,
  });

  final bool accepted;

  /// Feedback written by the model, shown to the user.
  final String message;

  /// Accepted photos for the current task, as counted by the backend.
  final int? photosFulfilled;

  final String? taskStatus;

  bool get completesTask => taskStatus == 'completed';

  factory PhotoCheck.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const PhotoCheck(accepted: false);
    final fulfilled = json['photosFulfilled'];
    return PhotoCheck(
      accepted: json['success'] == true,
      message: json['message']?.toString() ?? '',
      photosFulfilled: fulfilled is num ? fulfilled.toInt() : null,
      taskStatus: json['taskStatus']?.toString(),
    );
  }
}
