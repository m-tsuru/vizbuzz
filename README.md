<div align="center">
    <img alt="VizBuzz Logo" src="/assets/icon.png" width=300px>
    <h1>VizBuzz</h1>
</div>

macOS 向け 作業用目盛り付きタイマー

## ScreenShot

<div align="center">
    <img alt="スクリーンショット" src="/assets/vizbuzz.png" width=500px>
</div>

## Features

- 「カウントアップ」「カウントダウン」「リピート」に対応
- 半分経過で通知
- 常に最前面に表示することができる
- ログイン時に自動起動することができる

## Releases

`v` で始まるタグを push すると、GitHub Actions が macOS 向けのアプリをビルドし、Apple Developer 証明書を使わない ad-hoc 署名を付けて、zip ファイルを GitHub Release に添付します。

```sh
git tag v1.0.0
git push origin v1.0.0
```

Developer ID 署名と notarization は行っていないため、初回起動時は macOS のセキュリティ警告が表示される場合があります。その場合は、アプリを右クリックして「開く」を選択してください。

## Inspired by

- 「[VISUAL BAR TIMER（ビジュアルバータイマー）](https://www.kingjim.co.jp/sp/visual-bar-timer/vbt20/)」（キングジム）
    - 持ってます。おすすめ。買いましょう
    - ビジュアルバータイマーは株式会社キングジムの登録商標（登録番号 第6091713号）です

## LICENSE

MIT LICENSE
