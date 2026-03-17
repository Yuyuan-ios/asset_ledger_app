# 机账通支持页

这个目录提供一个可独立部署的静态支持页，可直接用于 App Store Connect 的 `Support URL`。

## 可配置项

编辑 `config.js` 中的以下字段：

- `supportEmail`
- `supportEmailSubject`
- `supportSiteUrl`
- `privacyPolicyUrl`
- `termsOfServiceUrl`
- `douyinHandle`
- `douyinUrl`
- `wechatLabel`

## 本地预览

在项目根目录执行：

```bash
cd support-site
python3 -m http.server 8080
```

然后访问 `http://localhost:8080`。

## 部署建议

### GitHub Pages

当前仓库已可直接使用 GitHub Pages。

1. 推送当前代码到 GitHub
2. 在 GitHub 仓库 `Settings -> Pages` 中将 Source 设为 `GitHub Actions`
3. 工作流会把 `support-site/` 目录发布为站点
4. 默认公开地址为：

```text
https://yuyuan-ios.github.io/asset_ledger_app/
```

5. 部署成功后，这个地址即可填入 App Store Connect 的 `Support URL`

### Vercel / Netlify

1. 导入当前仓库
2. 将发布目录设置为 `support-site`
3. 部署完成后拿到公开 URL
4. 同步更新 `support_feedback_config.dart` 与 `support-site/config.js`
