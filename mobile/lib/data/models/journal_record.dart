/// M2 Text Journal Data Model.
class JournalRecord {
  final String id;
  final String userId;
  final DateTime timestamp;
  final String encryptedContent; // AES-256 encrypted text
  final int wordCount;
  final double sentimentPolarity; // -1.0 to 1.0
  final double sentimentSubjectivity; // 0.0 to 1.0

  JournalRecord({
    required this.id,
    required this.userId,
    required this.timestamp,
    required this.encryptedContent,
    required this.wordCount,
    this.sentimentPolarity = 0.0,
    this.sentimentSubjectivity = 0.5,
  });

  Map<String, dynamic> toMap() {
    return {
      'journal_id': id,
      'user_id': userId,
      'timestamp_utc': timestamp.toUtc().toIso8601String(),
      'raw_text_encrypted': encryptedContent,
      'word_count': wordCount,
      'sentiment_polarity': sentimentPolarity,
      'sentiment_subjectivity': sentimentSubjectivity,
    };
  }

  factory JournalRecord.fromMap(Map<String, dynamic> map) {
    return JournalRecord(
      id: map['journal_id'] as String,
      userId: map['user_id'] as String,
      timestamp: DateTime.parse(map['timestamp_utc'] as String),
      encryptedContent: map['raw_text_encrypted'] as String,
      wordCount: map['word_count'] as int,
      sentimentPolarity: (map['sentiment_polarity'] as num?)?.toDouble() ?? 0.0,
      sentimentSubjectivity: (map['sentiment_subjectivity'] as num?)?.toDouble() ?? 0.5,
    );
  }
}

