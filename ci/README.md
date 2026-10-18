# CI 签名说明

Bealib 的 release 构建沿用 **debug 签名**（内部自用）。历史安装包（0.1.0 / 0.1.1）都由同一把 key 签名，
CI 必须使用同一个 key，否则老用户无法覆盖升级。

## 当前配置（已生效）

- keystore 已存放在 GitHub Secret：`ANDROID_DEBUG_KEYSTORE_BASE64`（base64 的 `debug.keystore`）。
- 仓库里**不再包含** keystore 文件（`.gitignore` 忽略 `ci/debug.keystore`），避免 public 仓库泄露签名 key。
- workflow 的 “Restore stable signing keystore” 步骤会从 Secret 解码到 `~/.android/debug.keystore`。

## 更新/更换 keystore

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("$env:USERPROFILE\.android\debug.keystore")) `
  | gh secret set ANDROID_DEBUG_KEYSTORE_BASE64 --repo ljh5866/bealib
```

若以后换正式 keystore：需要重新发布一次「新签名」安装包，老用户需卸载重装（Android 不允许跨签名覆盖升级）。
换法：在 `android/app/build.gradle` 增加 `signingConfigs.release`，workflow 中解码对应 secret 即可。
