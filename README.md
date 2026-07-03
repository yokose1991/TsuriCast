# TsuriCast（仮）

自分専用の釣果ログアプリ。釣果を記録すると、その時の気象・潮汐・位置を一緒に残す。たまった記録と予報をもとに「次に釣れそうなタイミング」を提示する、という個人向けアプリ。

ただし主役はアプリそのものではなく**設計**。最初は天気・Bedrock予測・通知をすべてモックで動かし、実APIもクラウドも課金もなしで、ローカルで最後まで動く状態を作る。本物（天気API・Bedrock・プッシュ通知）は後から差し替える。

## リポジトリ構成（モノレポ）

```
tsuricast/
├── README.md            ← このファイル（設計方針のドキュメント）
├── docker-compose.yml   ← app（nginx + PHP-FPM 同居）+ PostgreSQL
├── Makefile             ← make up / make test などの入口
├── docker/              ← Dockerfile・nginx・php・supervisord の設定
├── api/                 ← Laravel 12（API 専用バックエンド）
└── mobile/              ← Expo（モバイルクライアント）
```

Docker 構成は machiiro-dev と同方式（Amazon Linux 2023 ベースの1コンテナに nginx + PHP-FPM を supervisord で同居）。TsuriCast に不要な依存（Node / MeCab / ZBar / Python など）を除いたスリム版。

## 開発環境の起動

```bash
make up        # ビルド済みなら起動のみ（初回は make build が先）
make migrate   # マイグレーション
make test      # テスト（tsuricast_test DB を使用）
make shell     # app コンテナに入る
```

| 用途 | URL / ポート |
|---|---|
| API | http://localhost:8082 （machiiro-dev の 8081 と重複しないよう 8082） |
| PostgreSQL | localhost:5434 （同じく 5433 を避けて 5434） |

モバイル（Expo）:

```bash
cd mobile
npm install
npx expo start   # 表示される QR コードを実機の Expo Go で読み取る
```

**SDK は 54 に固定**（実機の Expo Go アプリと互換性を保つため。新しい SDK でプロジェクトを作ると Expo Go 側で incompatible エラーになる）。Xcode / Android Studio なしで、Expo Go 経由で実機確認できる。

- 実機と開発マシンは同一 Wi-Fi に接続する（クライアントアイソレーションのある社内 Wi-Fi では繋がらないので、その場合はテザリングを使う）
- 実機から API を叩く場合は `EXPO_PUBLIC_API_URL` に開発マシンの LAN IP（例 `http://192.168.x.x:8082`）を設定する。iOS シミュレータは `localhost`、Android エミュレータは `10.0.2.2` を使う

## 技術スタック

無料・ローカルで完結することを最優先に選定。外部サービスは後から差し替える想定で、開発中はモックで代替する。

| 領域 | 採用 | 選定理由 |
|---|---|---|
| 言語 / FW | PHP 8.3 / Laravel 12 | 勉強会の対象FW。規約と標準機構（FormRequest / Eloquent / Policy など）が揃い、ベストプラクティスを学ぶ題材として実例が豊富 |
| 開発環境 | Docker（nginx + PHP-FPM、ベースは Amazon Linux 2023） | Laravel Sail を使わず自前構成。本番想定の AWS 環境（Amazon Linux）に近い形で、サーバ構成を自分で把握する |
| DB | PostgreSQL（Docker） | FK・NOT NULL などの制約を厳格に効かせられ、設計方針2「DB と Model を一致させる」を本番に近い形で検証できる |
| テスト | PHPUnit | PHP 標準のテスティングフレームワークで Laravel にも同梱。資料・実例が最も多く、Pest も内部はこれ。基礎を学ぶ土台として情報量で勝る |
| 天気（想定API） | Open-Meteo | 無料・APIキー不要で、釣果と相関の強い気圧予報が取れる |
| AI予測（想定API） | Amazon Bedrock | 試したい技術。CatchPredictor の差し替え先 |
| 通知（想定） | Expo Push | モバイルクライアント想定（当面はログ出力のモック） |

開発中はすべてモック（Fake* / RuleBased* / Log*）で動かし、想定APIの実装は `.env` の切り替えで差し込む。

## 目指すこと

AIで初速が出せる時代。コードはすぐ生成できるが、それが10年・20年運用できる設計かを判断するのは人間の仕事として残る。

**最終ゴール：AIが生成したコードのアンチパターンを見極められるようになること。**

そのためには、判断の物差しとなるベストプラクティス（普遍的な設計原則＋Laravelの作法）を自分が知っている必要がある。知識は読むだけでは身につかないので、釣果アプリを実際に作りながら体に入れる。その過程で「長期運用に耐える設計を再現する」「モックとテストで品質を担保する」力も自然に身につく。

物差しとなるベストプラクティスは、下の「設計方針」にまとめている。

## 設計方針

AIが量産しがちなアンチパターンへの対処を、重要度順に並べた。各項目は「＝どのアンチパターンに効くか」を頭に示している。

普遍的な設計原則（関心の分離・依存性逆転など）を Laravel の標準機構で実装したもので、「Laravel だからこう書く」のか「どこでも通じる原則」なのかを意識すると、他フレームワークにも応用でき、AIコードの評価にも効く。

### 1. コントローラを薄く保つ

＝「ロジック集中」「似た実装の量産」への対処

コントローラは受け取って・呼んで・返すだけにし、検証は FormRequest、ロジックは Action / Service、整形は Resource、層をまたぐ入力は DTO、と役割ごとに置き場所を分ける。

### 2. DB と Model を一致させる

＝「DB と Model の不整合」「似た実装の量産」への対処

migration の FK・index・型・NOT NULL と、Eloquent の casts・リレーション・Enum を一致させ、DB とコードで定義がズレないようにする（同じ仕様を2か所に書いている状態なので、ズレると実行時に落ちる）。

### 3. 認可を Policy に集約する

＝「既存の作法を活かせない（認可漏れ）」への対処

「自分のデータか」の所有権チェックを Laravel 標準の Policy にまとめ、コントローラに直書きしない（ID を書き換えるだけで他人のデータを触れる事故＝IDOR を防ぐ）。 → https://laravel.com/docs/authorization

### 4. 書き込みをトランザクションで囲む

＝「途中で失敗して中途半端なデータが残る」への対処

複数テーブルにまたがる更新は `DB::transaction()` で囲み、全部成功か全部取り消しかのどちらかにする（不整合な状態を作らない）。

### 5. N+1 を避ける

＝「動くが、運用で遅くなるコード」への対処

一覧でリレーションを使うときは `with()` で先読みし、ループ内で都度クエリを発行しない（件数が増えてから表面化する性能劣化を、設計段階で潰しておく）。

### 6. 外部依存を interface とモックで閉じる

＝「本物に依存して差し替え・テストできない」への対処

天気や AI 予測のような外部サービスを本体から直接呼ばず、間に interface を挟む。ふだんは無料で動くモック実装を使い、本物（Open-Meteo や Bedrock）は呼び出し側を変えずに後から差し替える。

### 7. テストで設計を支える

＝「動いたと言うが、検証がないコード」への対処

外部依存をモックにして（方針6）外部に依存しないテストを書き、設計が壊れていないことを継続的に保証する（テストしやすさは、良い設計の結果でもある）。

### 8. 過剰に設計しない

＝「何でも抽象化して読めない」への対処

抽象化は差し替えが効く外部境界（天気/Bedrock/通知）に限り、単純な CRUD に Repository 層をかぶせるような、使う見込みのない抽象化はしない（YAGNI / KISS）。

## データモデル

- `users` … Laravel 標準テーブルをそのまま利用
- `catches` … user_id(FK) / fishing_spot_id(FK) / caught_at / species(Enum) / size_cm / air_pressure / tide_phase(Enum) / moon_age / memo
- `fishing_spots` … user_id(FK) / name / lat / lng / notify_enabled

```
User ─< Catch         User ─< FishingSpot ─< Catch
```

全レコードに user_id を持たせ、所有権を Policy で担保する（個人で閉じる方針の土台）。
