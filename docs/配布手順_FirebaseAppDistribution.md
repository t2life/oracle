# 配布手順: Firebase App Distribution（Android）

作成日: 2026-09-13
目的: テスターへメールで案内し、**更新通知つきで自動配信**する。
個人・身内配布のため Play ストア審査は不要。先行アプリ（十二天水地暦）と同じ基盤を使う。

---

## 0. 仕組み

```text
[開発PC] flutter build apk --release（リリース署名つき）
   └─ firebase appdistribution:distribute
        └─ [Firebaseプロジェクト] App Distribution
             └─ [テスターの実機] App Tester アプリ → ダウンロード/更新
```

- テスターをメールで招待 → **「App Tester」アプリ**から最新ビルドを取得する。
- 新版を配るたびに**更新通知**が届き、ワンタップで入れ替わる。
- **同一署名なら上書き更新**される（再インストール不要）。

---

## 1. 現状（2026-09-13 時点）

| 項目 | 値 |
|---|---|
| Firebase プロジェクト | `com-example-jyuunitensui-92e07`（**先行アプリと共用**） |
| App ID | `1:326703866263:android:6ab1f3c81ee8930c6624d2` |
| パッケージ名 | `com.apps2craft.oracle_mobile_app` |
| 署名 | リリース鍵（`CN=Apps2Craft`・PKCS12・RSA2048・30年） |
| firebase CLI | 15.22.3（ログイン済み） |

> **なぜ先行アプリのプロジェクトに相乗りするか**: 1つの Firebase プロジェクトに
> 複数のアプリを置けるため。配布先の方は先行アプリで App Tester を導入済みで、
> 同じアプリの中に新しいアプリとして並ぶ。再招待の手間が無い。

---

## 2. ★配布先はグループでなく個別に指定する

このプロジェクトの `testers` グループには**先行アプリのテスターが複数含まれる**。

```text
aug25th.jav8@gmail.com          … testers
inamasutakashi@gmail.com        … testers   ← オラクルカードの配布先ではない
```

∴ `--groups testers` で配ると**意図しない相手にも届く**。
オラクルカードは **`--testers <メールアドレス>` で個別指定**すること。

---

## 3. 毎回の配布

```powershell
cd C:\oracle_build\mobile_app
flutter build apk --release
firebase appdistribution:distribute `
  build\app\outputs\flutter-apk\app-release.apk `
  --app 1:326703866263:android:6ab1f3c81ee8930c6624d2 `
  --testers aug25th.jav8@gmail.com `
  --release-notes-file release_notes.txt
```

### 3.1 ★開発用の `--dart-define` を付けないこと

実機デバッグでは次を付けているが、**配布ビルドには絶対に付けない**。

| フラグ | 付けるとどうなるか |
|---|---|
| `--dart-define=PREMIUM_UNLOCKED=true` | 起動時に有料機能が全解放される。課金導線を検証できない |
| `--dart-define=ORACLE_API_BASE_URL=http://192.168.x.x:8000` | 開発機のLANアドレス。テスターの端末からは到達できない |

**素の `flutter build apk --release` が配布用**である。
接続先を指定しなければアプリ内エンジンで占うため、占い機能はすべて動く。

### 3.2 リリースノートは改行を含むのでファイルで渡す

`--release-notes` に複数行を直接渡すとシェルで壊れることがある（実際に1度失敗した）。
`--release-notes-file` を使う。

### 3.3 バージョンの上げ方

`pubspec.yaml` の `version:` を上げる（例 `0.1.0+1` → `0.1.1+2`）。
**同時に `lib/core/config/app_links.dart` の `appVersion` も合わせる**
（お問い合わせ本文に載る版数。`test/inquiry_mail_20260913_test.dart` が照合する）。

---

## 4. テスターを追加するとき

```powershell
firebase appdistribution:testers:add <メールアドレス> --project com-example-jyuunitensui-92e07
```

グループには入れず、配布時に `--testers` で列挙する（§2 の理由）。

---

## 5. テスター側の手順（初回のみ）

1. 招待メールを開く →「App Tester」をインストール
2. 招待されたアカウントでログイン → 最新ビルドが表示される
3. ダウンロード →「提供元不明のアプリ」を許可（初回のみ）→ インストール
4. 以後、新版を配ると App Tester に通知が出る

---

## 6. ★署名鍵の保全（最重要）

| ファイル | 場所 |
|---|---|
| `upload-keystore.jks` | `mobile_app/android/`（**Git管理外**） |
| `keystore.properties` | 同上（**Git管理外**） |
| 写し | `（リポジトリ外）_署名鍵バックアップ/`（README・指紋つき） |

**失うと同一署名での上書き更新ができなくなり**、配布済みの端末は
手動アンインストール→再インストールが必要になる（データは消える）。
Google Play へ公開したあとであれば、同じアプリとして更新できなくなる。

指紋（復元したものの照合用）:

```text
SHA-256 : D3:88:9A:A0:B8:76:36:15:99:28:2B:12:3F:4F:B7:B6:28:50:70:1C:0B:5C:E4:52:DC:E2:FF:27:21:89:EC:28
```

> バックアップは**同じディスク上**にある。ディスク故障・PC紛失からは守れないため、
> パスワード管理ソフトか暗号化した外付けドライブへもう1部を置くこと。

### 6.1 鍵が無い環境でもビルドは通る

`build.gradle.kts` は `keystore.properties` が在るときだけリリース署名を作り、
無ければ debug 署名のままにする。他の開発機やCIでビルドが落ちないようにするため。

**∴ 配布ビルドは必ず鍵が在る環境で作ること。** debug 署名のまま配ると、
後でリリース署名へ切り替えたときにテスターが手動アンインストールする羽目になる。

確認:

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\build-tools\37.0.0\apksigner.bat" verify --print-certs `
  build\app\outputs\flutter-apk\app-release.apk
```

`CN=Apps2Craft` であること（`CN=Android Debug` なら鍵が読めていない）。

---

## 7. 配布前チェックリスト

| # | 項目 | 確認方法 |
|---|---|---|
| 1 | テストが通る | `flutter analyze` / `flutter test` / バックエンド `pytest` |
| 2 | 開発用 `--dart-define` を付けていない | ビルドコマンドを目視（§3.1） |
| 3 | リリース署名になっている | §6.1 の `apksigner verify` |
| 4 | **実機で起動する** | 下記 §7.1 |
| 5 | 配布先が個別指定になっている | `--testers` であること（`--groups` でない） |

### 7.1 実機確認

```powershell
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
& $adb install -r build\app\outputs\flutter-apk\app-release.apk
& $adb shell am start -n com.apps2craft.oracle_mobile_app/.MainActivity
& $adb logcat -d -b crash | Select-String "apps2craft"
```

> 開発機に debug 署名の版が入っていると `INSTALL_FAILED_UPDATE_INCOMPATIBLE` になる。
> その場合は `adb uninstall com.apps2craft.oracle_mobile_app` してから入れる（データは消える）。

---

## 8. トラブルシュート

| 症状 | 対処 |
|---|---|
| `firebase: command not found` | `$env:Path += ";$env:APPDATA\npm"` |
| `An unexpected error has occurred`（アップロード中） | リリースノートの改行が原因のことがある。`--release-notes-file` を使う |
| `INSTALL_FAILED_UPDATE_INCOMPATIBLE` | 署名が違う。§7.1 の注を参照 |
| テスターに通知が来ない | `--testers` のアドレスが正しいか、招待を承認済みか |
| 同じAPKを2回配った | バイナリのハッシュで同一リリースに集約される（`re-uploaded already existing release`）。重複しない |

---

## 9. 今後

| # | 項目 | 備考 |
|---|---|---|
| 1 | Google Play 内部テストへの移行 | AAB と Play Console 登録が要る。署名鍵は本書のものをそのまま使える |
| 2 | 配布のバッチ化（`distribute.ps1`） | 先行アプリ `android/distribute.ps1` が参考になる。回数が増えたら作る |
| 3 | iOS の配布 | `docs/引き継ぎ_iOS移植_20260912.md` |
