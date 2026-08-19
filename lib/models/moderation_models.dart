enum ReportCategory {
  spam('spam', 'スパム'),
  harassment('harassment', '誹謗中傷を含む内容'),
  bullying('bullying', 'いじめ'),
  offensive('offensive', '不快に思う内容'),
  other('other', 'その他');

  const ReportCategory(this.databaseValue, this.label);

  final String databaseValue;
  final String label;

  static ReportCategory fromDatabase(String? value) {
    return values.firstWhere(
      (category) => category.databaseValue == value,
      orElse: () => ReportCategory.other,
    );
  }
}

class AccountSuspensionStatus {
  const AccountSuspensionStatus({
    required this.isSuspended,
    required this.reason,
    required this.suspendedAt,
  });

  final bool isSuspended;
  final String reason;
  final DateTime? suspendedAt;
}

class ModerationReport {
  const ModerationReport({
    required this.id,
    required this.reporterUsername,
    required this.reportedProfileId,
    required this.reportedUsername,
    required this.reportedUserId,
    required this.reportedAccountSuspended,
    required this.postId,
    required this.bookId,
    required this.review,
    required this.category,
    required this.details,
    required this.status,
    required this.resolution,
    required this.createdAt,
  });

  final int id;
  final String reporterUsername;
  final String reportedProfileId;
  final String reportedUsername;
  final String reportedUserId;
  final bool reportedAccountSuspended;
  final String? postId;
  final String bookId;
  final String review;
  final ReportCategory category;
  final String details;
  final String status;
  final String resolution;
  final DateTime createdAt;

  bool get isOpen => status == 'open';
}
