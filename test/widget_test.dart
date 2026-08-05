import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/screens/profile_onboarding_screen.dart';
import 'package:flutter_application_1/models/book.dart';
import 'package:flutter_application_1/models/post.dart';
import 'package:flutter_application_1/services/content_safety_service.dart';

void main() {
  group('個人情報変更用パスワード', () {
    test('大文字・小文字・数字を含む8〜20文字を受け付ける', () {
      expect(validatePrivacyPassword('Share123'), isNull);
      expect(validatePrivacyPassword('Abcdefg1Abcdefg1'), isNull);
    });

    test('条件を満たさないパスワードを拒否する', () {
      expect(validatePrivacyPassword('Short1'), isNotNull);
      expect(validatePrivacyPassword('lowercase1'), isNotNull);
      expect(validatePrivacyPassword('UPPERCASE1'), isNotNull);
      expect(validatePrivacyPassword('NoNumbers'), isNotNull);
      expect(validatePrivacyPassword('Abcdefghij12345678901'), isNotNull);
    });
  });

  group('年齢制限コンテンツ判定', () {
    const normalBook = Book(
      id: 'normal',
      title: '普通の小説',
      author: '著者',
      publisher: '出版社',
      pubDate: '',
      isbn: '',
      coverUrl: '',
      description: '一般向けの作品です。',
    );
    const adultBook = Book(
      id: 'adult',
      title: '作品集 R-18 成人向け',
      author: '著者',
      publisher: '出版社',
      pubDate: '',
      isbn: '',
      coverUrl: '',
    );

    test('区切り文字や大文字小文字の違いを吸収して判定する', () {
      expect(ContentSafetyService.isAdultBook(adultBook), isTrue);
      expect(ContentSafetyService.isAdultSearchQuery('ADULT-MAGAZINE'), isTrue);
      expect(ContentSafetyService.isAdultBook(normalBook), isFalse);
    });

    test('18歳の誕生日当日から成人として判定する', () {
      final today = DateTime(2026, 8, 5);
      expect(
        ContentSafetyService.isAtLeast18(DateTime(2008, 8, 5), onDate: today),
        isTrue,
      );
      expect(
        ContentSafetyService.isAtLeast18(DateTime(2008, 8, 6), onDate: today),
        isFalse,
      );
    });

    test('18歳未満向けの一覧から成人向け書籍を除外する', () {
      final filtered = ContentSafetyService.filterBooks(const [
        normalBook,
        adultBook,
      ], allowAdultContent: false);
      expect(filtered, [normalBook]);
    });
  });

  group('ネタバレ投稿', () {
    Post createPost(String comment, {bool isSpoiler = false}) {
      return Post(
        id: 'post',
        profileId: 'profile',
        bookId: 'book',
        rating: 5,
        comment: comment,
        createdAt: DateTime(2026, 8, 6),
        username: 'user',
        userAvatarUrl: '',
        bookTitle: 'title',
        bookAuthor: 'author',
        bookCoverUrl: '',
        isSpoiler: isSpoiler,
      );
    }

    test('専用フラグでネタバレ投稿を判定する', () {
      final post = createPost('感想本文', isSpoiler: true);
      expect(post.hasSpoiler, isTrue);
      expect(post.reviewText, '感想本文');
    });

    test('従来の本文プレフィックスにも対応する', () {
      final post = createPost('[ネタバレあり]\n感想本文');
      expect(post.hasSpoiler, isTrue);
      expect(post.reviewText, '感想本文');
    });

    test('ネタバレなしの従来プレフィックスは表示時に取り除く', () {
      final post = createPost('[ネタバレなし]\n感想本文');
      expect(post.hasSpoiler, isFalse);
      expect(post.reviewText, '感想本文');
    });
  });
}
