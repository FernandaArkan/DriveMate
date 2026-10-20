class ReminderItem {
  ReminderItem({
    this.id,
    this.vehicleId,
    required this.title,
    required this.message,
    required this.category, // 'Servis', 'Pajak', 'Sistem'
    required this.timeAgo,
    this.targetDate,
    this.targetMileage,
    this.isRead = false,
  });

  final int? id;
  final int? vehicleId;
  final String title;
  final String message;
  final String category;
  final String timeAgo;
  final String? targetDate;
  final int? targetMileage;
  bool isRead;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'vehicleId': vehicleId,
      'title': title,
      'message': message,
      'category': category,
      'timeAgo': timeAgo,
      'targetDate': targetDate,
      'targetMileage': targetMileage,
      'isRead': isRead ? 1 : 0,
    };
  }

  factory ReminderItem.fromMap(Map<String, dynamic> map) {
    return ReminderItem(
      id: map['id'] as int?,
      vehicleId: map['vehicleId'] as int?,
      title: map['title'] as String? ?? '',
      message: map['message'] as String? ?? '',
      category: map['category'] as String? ?? 'Sistem',
      timeAgo: map['timeAgo'] as String? ?? 'Baru saja',
      targetDate: map['targetDate'] as String?,
      targetMileage: map['targetMileage'] as int?,
      isRead: (map['isRead'] as int? ?? 0) == 1,
    );
  }
}
