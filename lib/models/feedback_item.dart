import 'dart:convert';

class FeedbackItem {
  const FeedbackItem({
    required this.id,
    required this.kesan,
    required this.pesan,
    required this.createdAt,
    this.rating = 5,
    this.userName,
  });

  final String id;
  final String kesan;
  final String pesan;
  final int rating;
  final DateTime createdAt;
  final String? userName;

  FeedbackItem copyWith({
    String? id,
    String? kesan,
    String? pesan,
    int? rating,
    DateTime? createdAt,
    String? userName,
  }) {
    return FeedbackItem(
      id: id ?? this.id,
      kesan: kesan ?? this.kesan,
      pesan: pesan ?? this.pesan,
      rating: rating ?? this.rating,
      createdAt: createdAt ?? this.createdAt,
      userName: userName ?? this.userName,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'kesan': kesan,
      'pesan': pesan,
      'rating': rating,
      'createdAt': createdAt.toIso8601String(),
      'userName': userName,
    };
  }

  factory FeedbackItem.fromMap(Map<String, dynamic> map) {
    return FeedbackItem(
      id: map['id']?.toString() ?? '',
      kesan: map['kesan']?.toString() ?? '',
      pesan: map['pesan']?.toString() ?? '',
      rating: (map['rating'] as num?)?.toInt() ?? 5,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      userName: map['userName']?.toString(),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory FeedbackItem.fromJson(String source) =>
      FeedbackItem.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
