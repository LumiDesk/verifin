# 开发习惯

## 预览方式
日常开发优先使用 Web 预览。需要给用户稳定验收地址时，先执行 `flutter build web`，再在 `build/web` 下启动静态服务，例如：

```bash
python3 -m http.server 8080 --bind 0.0.0.0
```

这种方式比 debug web-server 更适合直接验收页面，也能减少 source map 噪声。若用户反馈白屏，先检查 `/`、`/flutter_bootstrap.js`、`/main.dart.js` 是否返回 `200`，再建议用户强制刷新或使用无痕窗口排除缓存影响。

## 提交节奏
不要把所有改动混到最后一次提交。每完成一个相对独立的模块就提交一次，例如数据模型、页面结构、样式优化、文档同步分别提交。提交信息保持 `type: summary` 格式，不包含 AI 或 Codex 署名。

## 文档同步
每次修改功能、开发流程、数据结构或预览方式，都要同步检查 `README.md`、`AGENTS.md`、`docs/product.md` 和 `docs/dev/`。如果行为或流程变化已经影响用户测试或后续开发，需要在同一次变更里更新文档。
