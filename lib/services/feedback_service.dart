import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/feedback_item.dart';

class FeedbackService extends ChangeNotifier {
  FeedbackService._internal();

  static final FeedbackService instance = FeedbackService._internal();

  static const String keyFeedbacks = 'local_user_feedbacks';

  List<FeedbackItem> _feedbacks = [];
  bool _isLoaded = false;

  List<FeedbackItem> get feedbacks => List.unmodifiable(_feedbacks);
  bool get isLoaded => _isLoaded;

  Future<List<FeedbackItem>> loadFeedbacks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(keyFeedbacks);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _feedbacks = decoded
              .map((item) => FeedbackItem.fromMap(Map<String, dynamic>.from(item)))
              .toList();
          _feedbacks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        }
      } else {
        _feedbacks = [];
      }
    } catch (e) {
      debugPrint('Error loading local feedbacks: $e');
      _feedbacks = [];
    } finally {
      _isLoaded = true;
      notifyListeners();
    }
    return _feedbacks;
  }

  Future<bool> saveFeedback({
    required String kesan,
    required String pesan,
    int rating = 5,
    String? userName,
  }) async {
    try {
      final newItem = FeedbackItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        kesan: kesan.trim(),
        pesan: pesan.trim(),
        rating: rating,
        createdAt: DateTime.now(),
        userName: userName,
      );

      _feedbacks.insert(0, newItem);

      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(_feedbacks.map((f) => f.toMap()).toList());
      await prefs.setString(keyFeedbacks, jsonString);

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error saving local feedback: $e');
      return false;
    }
  }

  Future<bool> deleteFeedback(String id) async {
    try {
      _feedbacks.removeWhere((item) => item.id == id);
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(_feedbacks.map((f) => f.toMap()).toList());
      await prefs.setString(keyFeedbacks, jsonString);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deleting local feedback: $e');
      return false;
    }
  }

  Future<void> clearAll() async {
    try {
      _feedbacks.clear();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(keyFeedbacks);
      notifyListeners();
    } catch (e) {
      debugPrint('Error clearing local feedbacks: $e');
    }
  }
}
