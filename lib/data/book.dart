import 'package:flutter/foundation.dart';

class Book {
  final String id; // Unique identifier (ISBN if available, else generated)
  final String title;
  final String author;
  final String publisher;
  final String pubDate; // Publication year or full date
  final String isbn;
  final String coverUrl; // High‑resolution image URL from Rakuten
  final double ratingAvg;

  const Book({
    required this.id,
    required this.title,
    required this.author,
    required this.publisher,
    required this.pubDate,
    required this.isbn,
    required this.coverUrl,
    this.ratingAvg = 0.0,
  });

  // Factory from NDL JSON (simplified)
  factory Book.fromNdlJson(Map<String, dynamic> json) {
    // NDL provides title, creator (author), publisher, dcdate (pub date), and isbn.
    final title = json['title'] ?? '不明なタイトル';
    final author = json['creator'] ?? '不明な著者';
    final publisher = json['publisher'] ?? '不明な出版社';
    final pubDate = json['dcdate'] ?? '';
    final isbn = json['isbn'] ?? '';
    // NDL では表紙画像が無いため、空文字で保持。後で Rakuten で補完。
    return Book(
      id: isbn.isNotEmpty ? isbn : UniqueKey().toString(),
      title: title,
      author: author,
      publisher: publisher,
      pubDate: pubDate,
      isbn: isbn,
      coverUrl: '',
    );
  }

  // Factory from Rakuten JSON (simplified)
  factory Book.fromRakutenJson(Map<String, dynamic> json) {
    final title = json['title'] ?? '不明なタイトル';
    final author = (json['author'] as List?)?.join(', ') ?? '不明な著者';
    final publisher = json['publisherName'] ?? '不明な出版社';
    final pubDate = json['salesDate'] ?? '';
    final isbn = json['isbn'] ?? '';
    final coverUrl = json['largeImageUrl'] ?? '';
    final id = isbn.isNotEmpty ? isbn : UniqueKey().toString();
    return Book(
      id: id,
      title: title,
      author: author,
      publisher: publisher,
      pubDate: pubDate,
      isbn: isbn,
      coverUrl: coverUrl,
    );
  }

  Book copyWith({
    String? id,
    String? title,
    String? author,
    String? publisher,
    String? pubDate,
    String? isbn,
    String? coverUrl,
    double? ratingAvg,
  }) {
    return Book(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      publisher: publisher ?? this.publisher,
      pubDate: pubDate ?? this.pubDate,
      isbn: isbn ?? this.isbn,
      coverUrl: coverUrl ?? this.coverUrl,
      ratingAvg: ratingAvg ?? this.ratingAvg,
    );
  }
}
