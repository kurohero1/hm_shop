# ユースケース図・記述

## 1. ユースケース図 (Mermaid)

```mermaid
usecaseDiagram
    actor User as "User"
    actor GMaps as "Google Maps API"
    actor Firebase as "Firebase Auth"
    actor WeatherAPI as "OpenWeatherMap API"

    package "Sanpo AI (HM Shop)" {
        usecase "Login / Register" as UC1
        usecase "Logout" as UC2
        usecase "Search Route" as UC3
        usecase "Show Map & Route" as UC4
        usecase "Search Spots" as UC5
        usecase "Check Steps / Distance" as UC6
        usecase "Check Weather" as UC7
    }

    User --> UC1
    User --> UC2
    User --> UC3
    User --> UC4
    User --> UC6
    User --> UC7

    UC1 ..> Firebase : Auth
    UC2 ..> Firebase : Sign out
    UC3 ..> GMaps : Directions API
    UC4 ..> GMaps : Maps SDK
    UC5 ..> GMaps : Places API
    UC3 <.. UC5 : extend
    UC7 ..> WeatherAPI : Weather
```

## 2. ユースケース記述

### UC1: ログイン/登録
*   **概要**: ユーザーがアプリを利用するためにアカウントを作成、または既存のアカウントでログインする。
*   **アクター**: ユーザー
*   **事前条件**: なし
*   **事後条件**: ユーザーが認証され、メイン画面に遷移する。
*   **主な流れ**:
    1.  ユーザーがメールアドレスとパスワードを入力する。
    2.  システムがFirebase Authに認証を要求する。
    3.  認証成功後、システムはメイン画面を表示する。

### UC3: ルート検索
*   **概要**: 出発地、目的地（および任意の経由地）を指定して、ウォーキングルートを検索する。
*   **アクター**: ユーザー
*   **事前条件**: ログイン済みであること。
*   **事後条件**: 地図上にルートが表示される。
*   **主な流れ**:
    1.  ユーザーが出発地、目的地を入力する（任意で経由地も入力）。
    2.  ユーザーが入力を確定する（フォーカスを外す等）。
    3.  システムがGoogle Maps Directions APIに経路情報をリクエストする。
    4.  システムが取得した経路を地図上に描画する。

### UC5: スポット検索・表示
*   **概要**: 設定されたフィルタ（コンビニ、カフェ等）に基づき、ルート周辺のスポットを検索・表示する。
*   **アクター**: ユーザー
*   **事前条件**: ルートが表示されていること。
*   **主な流れ**:
    1.  ユーザーが「コンビニさんぽ」や「買い物さんぽ」などのフィルタを選択する。
    2.  システムがルート周辺の施設をGoogle Places APIで検索する。
    3.  該当する施設が地図上にマーカーとして表示される。

### UC6: 歩数・距離確認
*   **概要**: 日々の歩数と移動距離（週間グラフ）を確認する。
*   **アクター**: ユーザー
*   **事前条件**: アプリがインストールされており、歩数が記録されていること。
*   **主な流れ**:
    1.  ユーザーがメイン画面を表示する。
    2.  システムがローカルストレージ（SharedPreferences）から歩数データを読み込む。
    3.  システムが当日の歩数と週間移動距離グラフを表示する。
