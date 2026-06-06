class Book {
  final String id;
  final String title;
  final String author;
  final String coverUrl;
  final String genre;
  final String description;
  final double ratingAvg;

  Book({
    required this.id,
    required this.title,
    required this.author,
    required this.coverUrl,
    required this.genre,
    required this.description,
    required this.ratingAvg,
  });

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      author: json['author'] ?? '',
      coverUrl: json['cover_url'] ?? '',
      genre: json['genre'] ?? '',
      description: json['description'] ?? '',
      ratingAvg: (json['rating_avg'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'cover_url': coverUrl,
      'genre': genre,
      'description': description,
      'rating_avg': ratingAvg,
    };
  }
}
