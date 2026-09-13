import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:oracle_mobile_app/core/config/app_links.dart';
import 'package:oracle_mobile_app/core/support/inquiry_form.dart';

/// お問い合わせをメーラー方式へ変えた件（2026-09-13 承認）。
///
/// ★アプリには公開サーバーが無く、送信は**利用者のメールアプリ**に委ねる。
/// ∴ アプリ側が保証できるのは「**何を渡すか**」だけであり、そこを固定する。
void main() {
  group('件名', () {
    test('アプリ名を前置し、種類で終わる', () {
      // 受信箱で他の連絡と混ざらず、種類で仕分けできるようにするため。
      final subject = InquiryForm.subject(
        appName: '日本神話オラクルロンカード',
        topicLabel: '不具合',
      );
      expect(subject, '[日本神話オラクルロンカード] 不具合');
    });
  });

  group('本文', () {
    test('入力が先頭に来て、環境情報が末尾に付く', () {
      // ★不具合の切り分けには「どの版で・どの端末で」が要る。
      final body = InquiryForm.body(
        input: '落ちます',
        environmentNote: '以下は自動で付記しています。',
        environment: 'アプリ: 0.1.0+1\nOS: android 15',
      );
      expect(body.startsWith('落ちます'), isTrue);
      expect(body.contains('以下は自動で付記しています。'), isTrue);
      expect(body.contains('アプリ: 0.1.0+1'), isTrue);
      expect(body.contains('--------------------'), isTrue);
    });

    test('入力末尾の空白は落とすが、先頭は保つ', () {
      final body = InquiryForm.body(
        input: '  あ  \n\n',
        environmentNote: 'note',
        environment: 'env',
      );
      expect(body.startsWith('  あ'), isTrue);
      expect(body.contains('あ  \n\n\n'), isFalse);
    });
  });

  group('送信可否', () {
    test('空では送れない', () {
      // 空メールが届いても、こちらは何も返せない。
      expect(InquiryForm.canSend(''), isFalse);
      expect(InquiryForm.canSend('   \n  '), isFalse);
      expect(InquiryForm.canSend('あ'), isTrue);
    });

    test('上限を超えたら送れない', () {
      expect(InquiryForm.maxBodyLength, 4000);
      expect(InquiryForm.canSend('あ' * 4000), isTrue);
      expect(InquiryForm.canSend('あ' * 4001), isFalse);
    });

    test('残り文字数は超過を負で表す', () {
      // ★0で頭打ちにしない。何文字削ればよいか分からなくなる。
      expect(InquiryForm.remaining(''), 4000);
      expect(InquiryForm.remaining('あ' * 4000), 0);
      expect(InquiryForm.remaining('あ' * 4005), -5);
    });
  });

  group('mailto URI', () {
    test('宛先・件名・本文が復元できる', () {
      final uri = InquiryForm.mailtoUri(
        to: 'support@example.com',
        subject: '[アプリ] 不具合',
        body: '本文です\n2行目',
      );
      expect(uri.scheme, 'mailto');
      expect(uri.path, 'support@example.com');
      expect(uri.queryParameters['subject'], '[アプリ] 不具合');
      expect(uri.queryParameters['body'], '本文です\n2行目');
    });

    test('空白を + にしない（メーラーがそのまま文字として出すため）', () {
      final uri = InquiryForm.mailtoUri(
        to: 'a@b.c',
        subject: 'a b',
        body: 'c d',
      );
      expect(uri.toString().contains('+'), isFalse);
      expect(uri.toString().contains('%20'), isTrue);
    });

    test('改行と記号がエンコードされる', () {
      final uri = InquiryForm.mailtoUri(
        to: 'a@b.c',
        subject: 's',
        body: '1行目\n2行目&3=4',
      );
      final text = uri.toString();
      expect(text.contains('\n'), isFalse);
      // & と = は本文の区切りと衝突するため、必ず包まれていること。
      expect(text.contains('%26'), isTrue);
      expect(text.contains('%3D'), isTrue);
    });
  });

  group('宛先と版数', () {
    test('宛先は設定の1箇所から採る', () {
      // ★画面に直書きすると、変更時に片方だけ直されて届かなくなる。
      expect(AppLinks.supportEmail.isNotEmpty, isTrue);
      expect(AppLinks.supportEmail.contains('@'), isTrue);
    });

    test('appVersion が pubspec.yaml と一致する', () {
      // ★写しなのでずれる。ずれると問い合わせに載る版数が嘘になる。
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final match = RegExp(r'^version:\s*(\S+)', multiLine: true)
          .firstMatch(pubspec);
      expect(match, isNotNull, reason: 'pubspec.yaml に version が無い');
      expect(
        AppLinks.appVersion,
        match!.group(1),
        reason: 'AppLinks.appVersion を pubspec.yaml の version に合わせること',
      );
    });
  });
}
