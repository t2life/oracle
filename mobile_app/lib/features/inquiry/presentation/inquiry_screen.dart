import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_links.dart';
import '../../../core/state/app_state_scope.dart';
import '../../../core/support/inquiry_form.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/speaker_toggle.dart';

/// お問い合わせ（U-17）。
///
/// ★2026-09-13 変更: サーバーへ送る方式をやめ、**利用者のメールアプリ**へ渡す。
/// 以前はサーバー未公開・機内モードでは送信ボタンごと無効だったが、
/// メーラーに委ねればその制約が消える。返信先は送信元がそのまま使えるため、
/// メールアドレスの入力欄も不要になった（先行アプリと同じ設計）。
class InquiryScreen extends StatefulWidget {
  const InquiryScreen({super.key});

  @override
  State<InquiryScreen> createState() => _InquiryScreenState();
}

/// 問い合わせの種類。件名の仕分けと、本文の記入例に使う。
enum _Topic { general, billing, bug }

class _InquiryScreenState extends State<InquiryScreen> {
  final TextEditingController _bodyController = TextEditingController();
  _Topic _topic = _Topic.general;

  @override
  void initState() {
    super.initState();
    // 残り文字数を出すため、入力のたびに描き直す。
    _bodyController.addListener(_onChanged);
  }

  @override
  void dispose() {
    _bodyController.removeListener(_onChanged);
    _bodyController.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  String _topicLabel(AppLocalizations l10n) => switch (_topic) {
        _Topic.general => l10n.categoryGeneral,
        _Topic.billing => l10n.categoryBilling,
        _Topic.bug => l10n.categoryBug,
      };

  String _example(AppLocalizations l10n) => switch (_topic) {
        _Topic.general => l10n.inquiryExampleGeneral,
        _Topic.billing => l10n.inquiryExampleBilling,
        _Topic.bug => l10n.inquiryExampleBug,
      };

  /// 端末とアプリの情報。切り分けに要るため本文へ自動で付ける。
  /// 依存を増やさないため `dart:io` だけで採れる範囲に留める。
  String _environment() =>
      'アプリ: ${AppLinks.appVersion}\n'
      'OS: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}';

  Future<void> _send() async {
    final l10n = AppLocalizations.of(context)!;
    final input = _bodyController.text;
    if (!InquiryForm.canSend(input)) {
      return;
    }

    final uri = InquiryForm.mailtoUri(
      to: AppLinks.supportEmail,
      subject: InquiryForm.subject(
        appName: AppLinks.shareSubject,
        topicLabel: _topicLabel(l10n),
      ),
      body: InquiryForm.body(
        input: input,
        environmentNote: l10n.inquiryEnvironmentNote,
        environment: _environment(),
      ),
    );

    final failed = l10n.inquiryMailFailed(AppLinks.supportEmail);
    var launched = false;
    try {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Exception {
      // メールアプリが1つも無い端末では例外になる。握り潰さず下で宛先を示す。
      launched = false;
    }
    if (!launched && mounted) {
      // ★黙って何も起きないのが最悪。開けないときは宛先を文字で見せる。
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failed), duration: const Duration(seconds: 8)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final input = _bodyController.text;
    final remaining = InquiryForm.remaining(input);
    final tooLong = remaining < 0;

    return Scaffold(
      appBar: buildOracleAppBar(context, l10n.inquiryScreenTitle),
      body: OracleStateBuilder(
        builder: (context, state) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 何が起きるかを先に伝える。押してからメーラーが開くと驚くため。
              Card(
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(l10n.inquiryMailIntro),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<_Topic>(
                initialValue: _topic,
                decoration: InputDecoration(labelText: l10n.categoryLabel),
                items: [
                  DropdownMenuItem(
                    value: _Topic.general,
                    child: Text(l10n.categoryGeneral),
                  ),
                  DropdownMenuItem(
                    value: _Topic.billing,
                    child: Text(l10n.categoryBilling),
                  ),
                  DropdownMenuItem(
                    value: _Topic.bug,
                    child: Text(l10n.categoryBug),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() => _topic = value);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _bodyController,
                decoration: InputDecoration(
                  labelText: l10n.inquiryBodyLabel,
                  // ★記入例は**プレースホルダ**で出す。既定値として本文へ入れると、
                  // 消し忘れがそのまま送られ、読む内容が例文で埋まる。
                  hintText: _example(l10n),
                  alignLabelWithHint: true,
                  border: const OutlineInputBorder(),
                ),
                maxLines: 8,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  tooLong
                      ? l10n.inquiryTooLong(-remaining)
                      : l10n.inquiryRemaining(remaining),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: tooLong
                            ? Theme.of(context).colorScheme.error
                            : null,
                      ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: InquiryForm.canSend(input) ? _send : null,
                icon: const Icon(Icons.mail_outline),
                label: Text(l10n.inquiryOpenMail),
              ),
            ],
          );
        },
      ),
    );
  }
}
