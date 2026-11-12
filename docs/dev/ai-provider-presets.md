# AI 渠道预设与模型发现

> 本文件记录 AI 渠道预设与模型发现的当前实现、数据契约和验收边界。
> 技术取舍摘要另见 [tech-decisions.md](tech-decisions.md)，组件入口见
> [components.md](../design/components.md)。
>
> 调研日期：2026-10-18。
>
> 外部参考：[cc-switch](https://github.com/farion1231/cc-switch)，调研时
> `main` 提交为 `77c6dc793d4fbc13bc96163d55d747b02f887a8b`。

## 1. 用户体验

AI 设置当前提供：

1. 用户从分组宫格中选择预设渠道；
2. 预设自动带出固定的 OpenAI-compatible Base URL 与模型列表规则，工具调用协议恢复为自动；
3. 用户可以直接点击模型输入框右侧的下箭头，从远端获取该渠道当前可用模型；API Key 可空；
4. 获取成功后，在统一底部弹层中搜索、查看分组并选择模型，选中值自动回填模型输入框；
5. 模型输入框始终允许手动输入；远端列表失败或渠道不支持枚举时，不阻断保存；
6. 所有改动遵循设置页自动保存语义：选择、切换或停止输入后立即落盘；已配置渠道时切换先确认，保存失败才提示。

渠道选择器使用与账户图标选择器一致的信息架构：

- 顶部搜索；
- 横向分组筛选；
- 宫格中上方 Logo、下方厂商名称和一句简短说明；
- 搜索结果改为列表，展示 Logo、名称、完整说明与分组；
- 当前渠道显示选中标记；
- 始终提供“自定义 OpenAI 兼容渠道”。

本功能只改变 AI 连接配置与模型发现，不改变 Agent 工具、账目口径、页面内对话状态
或 AI 记账解析逻辑。

## 2. 实现范围与边界

AI 配置在 [ai_settings.dart](../../lib/app/ai/ai_settings.dart) 中保存：

- `providerId`
- `baseUrl`
- `apiKey`
- `model`
- `modelListUrl`
- `toolCallMode`

`AiSettings.isConfigured` 只要求 Base URL 与模型非空；API Key 可为空。
`AiChatPage`、AI 记账和截图识账共用这份配置。

传输层固定使用：

- `{baseUrl}/chat/completions`；
- API Key 非空时发送 `Authorization: Bearer {apiKey}`，为空时不发送鉴权头；
- OpenAI Chat Completions 请求体；
- 原生 SSE 与 Tool Calls。

因此当前只适配“Bearer 或空鉴权、OpenAI Chat Completions、模型列表可由 HTTP GET
获取”的渠道。Anthropic Messages、OpenAI Responses、AWS Bedrock、Azure 管理面模型
枚举等协议不在范围内；如果后续要接，需要另立协议适配设计，不能把渠道名和协议名
混在一起。

## 3. cc-switch 调研结论

### 3.1 可借鉴的部分

cc-switch 的模型发现能力拆分得很清楚：

- 前端入口：
  `src/lib/api/model-fetch.ts`
- Tauri 命令：
  `src-tauri/src/commands/model_fetch.rs`
- 纯后端逻辑：
  `src-tauri/src/services/model_fetch.rs`
- 模型选择器：
  `src/components/providers/forms/shared/ModelDropdown.tsx`
- 用户说明：
  `docs/user-manual/zh/2-providers/2.1-add.md`

其核心不是“写死一个 `/v1/models`”，而是：

1. 支持预设的精确 `modelsUrl` 覆盖；
2. 没有覆盖时按 Base URL 生成最多几个候选地址；
3. Base URL 已经带 `/v1`、`/v4` 等版本段时，拼 `{base}/models`；
4. Base URL 带 `/anthropic`、`/api/anthropic`、`/api/coding` 等兼容子路径时，剥离
   后缀后依次尝试根路径；
5. 解析两类响应：
   - `{"data":[{"id":"...","owned_by":"..."}]}`
   - `{"models":[{"slug":"..."}]}`，也兼容 `models[].id`
6. 对错误响应做密钥脱敏，404/405 时继续试下一个候选，其他错误直接结束；
7. 前端按 `ownedBy` 分组；响应未提供 `owned_by` 时，用模型 ID 中 `/` 前的厂商
   前缀作为分组键。支持搜索模型名和厂商名，选中即回填。

### 3.2 不应照搬的部分

- 不把 Tauri/Rust 实现搬进 Flutter；本项目已有 `dart:io HttpClient` 和统一错误码，
  用纯 Dart 实现即可。
- 不复制 cc-switch 的全部第三方中转站、赞助商和 Coding Plan 渠道。内置渠道应优先
  官方平台、主流模型厂商和成熟聚合平台，避免把营销渠道固化成产品目录。
- 不依赖 cc-switch 的远程图标 URL。Veri Fin 本地优先，渠道 Logo 必须随 APK 打包，
  离线可用。
- 不把 Base URL 猜测当成通用契约。已知渠道使用显式模型列表 URL；只有自定义渠道才
  使用候选回退。

### 3.3 许可证与商标

cc-switch 使用 MIT。其 `src/icons/extracted/` 中不少 SVG 带
`lobe-icons-*` 标识，对应 LobeHub `lobe-icons`，同样使用 MIT。可以提取 SVG/PNG
素材，但需要：

- 在仓库内保留来源说明、上游项目和许可证文本；
- 不改动 Logo 的比例、颜色和内部结构；
- 只用于“该渠道可被选择”的识别用途，不暗示官方合作或背书；
- 不把第三方商标注册为自己的品牌；
- 只引入实际使用的渠道 Logo，避免无意义地扩大包体与商标素材面。

## 4. 渠道数据模型

渠道注册表位于 `lib/app/ai/ai_provider_presets.dart`，用不可变静态数据描述渠道。

```dart
enum AiProviderGroup {
  chinaOfficial,
  globalOfficial,
  aggregator,
  local,
  custom,
}

class AiProviderPreset {
  const AiProviderPreset({
    required this.id,
    required this.brandName,
    required this.group,
    required this.baseUrl,
    required this.iconAsset,
    this.modelListUrl,
    this.searchTerms = const <String>[],
  });

  final String id;
  final String brandName;
  final AiProviderGroup group;
  final String baseUrl;
  final String? modelListUrl;
  final String? iconAsset;
  final List<String> searchTerms;

  bool get isCustom => group == AiProviderGroup.custom;
}
```

规则：

- `id` 一经发布不得复用；显示名可以更新，ID 不能承载版本号或模型名。
- `baseUrl` 是 `chatCompletionsUrl` 的基础，不包含 `/chat/completions`。
- 非标准模型列表路径必须用 `modelListUrl` 显式声明，不能靠通用字符串猜测。
- Logo 使用随 APK 打包的本地资源；自定义渠道没有品牌 Logo。
- API Key 对所有渠道都可选；为空时请求不发送 `Authorization`，由渠道自行返回
  401/403 或其他业务错误。
- 渠道展示名是品牌专名，可保留英文；分类名和厂商说明必须写入中英文 ARB。

## 5. 配置模型与迁移

`AiSettings` 新增：

- `providerId`：当前渠道稳定 ID；旧配置缺失时回退 `custom`；
- `modelListUrl`：仅自定义渠道使用的高级可选覆盖；预设渠道由注册表提供。

配置 JSON：

```json
{
  "providerId": "deepseek",
  "baseUrl": "https://api.deepseek.com/v1",
  "apiKey": "",
  "model": "deepseek-flash",
  "toolCallMode": "auto",
  "modelListUrl": ""
}
```

兼容要求：

- 旧版 `verifin.ai.v1` 继续可读；没有 `providerId` 时保留原有三项配置并显示为
  “自定义 OpenAI 兼容渠道”；
- 不因为启动时匹配到某个已知 Base URL 就静默改写旧配置；
- 用户重新选择预设渠道时才写入新的 Base URL 与渠道 ID；
- 未知或已删除的 `providerId` 不得让 AI 不可用，按自定义渠道保留原 URL；
- `AiSettings == / hashCode`、`toJson`、`fromJson`、测试夹具同步更新；
- AI 配置仍只存设备 KV，不进备份，初始化数据时保留。

`isConfigured` 改为：

- Base URL、模型必填；
- API Key 不参与 `isConfigured` 判定，允许为空；
- 空 Key 时发送不含 `Authorization` 的请求；
- 未知 ID 仍按自定义渠道处理，但同样允许空 Key。

## 6. 渠道目录

### 6.1 内置渠道

“自定义 OpenAI 兼容”作为常驻兜底入口，不计入 8 个预设。以下组合已确认：

| ID | 显示名 | 分组 | Base URL | 模型列表 | 探测事实 |
|---|---|---|---|---|---|
| `openai` | OpenAI | 国际官方 | `https://api.openai.com/v1` | `+ /models` | 标准 OpenAI 接口 |
| `deepseek` | DeepSeek | 国内官方 | `https://api.deepseek.com/v1` | `+ /models` | 无效 Key 返回 401；官方文档为 `GET /models` |
| `volcengine-ark` | 火山方舟 | 国内官方 | `https://ark.cn-beijing.volces.com/api/v3` | `+ /models` | 无效 Key 返回 401 |
| `kimi` | Kimi（Moonshot） | 国内官方 | `https://api.moonshot.cn/v1` | `+ /models` | 无效 Key 返回 401 |
| `zhipu-glm` | 智谱 GLM | 国内官方 | `https://open.bigmodel.cn/api/paas/v4` | `+ /models` | 无效 Key 返回 401 |
| `dashscope` | 阿里云百炼 | 国内官方 | `https://dashscope.aliyuncs.com/compatible-mode/v1` | `+ /models` | 无效 Key 返回 401 |
| `openrouter` | OpenRouter | 聚合平台 | `https://openrouter.ai/api/v1` | `+ /models` | 公开列表返回 200 |
| `ollama` | Ollama | 本地服务 | `http://localhost:11434/v1` | `+ /models` | 本地未启动，需真机/局域网验证 |
| `custom` | 自定义 OpenAI 兼容 | 自定义 | 用户填写 | 可选高级覆盖；否则按 Base URL 推导 | 保留现有手填能力 |

OpenAI 标准地址未发送无效 Key 做探测，避免无意义请求；其模型列表沿用官方
OpenAI-compatible 契约。

### 6.2 未内置的渠道

以下渠道当前没有内置入口，需要时通过“自定义 OpenAI 兼容”填写地址接入。表中的
模型列表状态来自 2026-10-18 的无效 Key 探测；401/403/400 只说明路由存在，实际
可用性仍取决于用户端点和 Key。

| 分组 | 渠道 | Base URL | 模型列表状态 |
|---|---|---|---|
| 国内官方 | Kimi Global | `https://api.moonshot.ai/v1` | 需真实 Key 验证 |
| 国内官方 | 智谱 GLM Global | 待官方文档复核（不要从 Coding Plan 地址推断） | 待复核 |
| 国内官方 | 百炼国际 | `https://dashscope-intl.aliyuncs.com/compatible-mode/v1` | 401 |
| 国内官方 | MiniMax Global | `https://api.minimax.io/v1` | 需真实 Key 验证 |
| 国内官方 | MiniMax | `https://api.minimax.cn/v1` | 401 |
| 国内官方 | 阶跃星辰 | `https://api.stepfun.com/v1` | 401 |
| 国内官方 | 腾讯混元 | `https://api.hunyuan.cloud.tencent.com/v1` | 401 |
| 国内官方 | 腾讯 TokenHub | `https://tokenhub.tencentmaas.com/v1` | 401 |
| 国内官方 | 百度千帆 | `https://qianfan.baidubce.com/v2` | 403，需真实 Key 验证 |
| 国内官方 | 讯飞星火 | `https://spark-api-open.xf-yun.com/v1` | 401 |
| 国内官方 | 百川智能 | `https://api.baichuan-ai.com/v1` | 401 |
| 国内官方 | 小米 MiMo | `https://api.xiaomimimo.com/v1` | 401 |
| 国内官方 | 蚂蚁百灵 | `https://api.ant-ling.com/v1` | 401 |
| 国内官方 | 长猫 LongCat | `https://api.longcat.chat/openai/v1` | 401 |
| 聚合平台 | 模力方舟 | `https://api.moark.com/v1` | 401 |
| 聚合平台 | AiHubMix | `https://aihubmix.com/v1` | 公开列表返回 200 |
| 聚合平台 | 硅基流动 | `https://api.siliconflow.cn/v1` | 401 |
| 聚合平台 | ModelScope | `https://api-inference.modelscope.cn/v1` | 公开列表返回 200 |
| 聚合平台 | PPIO | `https://api.ppio.com/openai/v1` | 公开列表返回 200 |
| 聚合平台 | Novita AI | `https://api.novita.ai/openai/v1` | 公开列表返回 200 |
| 聚合平台 | NVIDIA NIM | `https://integrate.api.nvidia.com/v1` | 公开列表返回 200 |
| 聚合平台 | Hugging Face Router | `https://router.huggingface.co/v1` | 公开列表返回 200 |
| 聚合平台 | Nebius Token Factory | `https://api.tokenfactory.nebius.com/v1` | 401 |
| 聚合平台 | SambaNova | `https://api.sambanova.ai/v1` | 公开列表返回 200 |
| 聚合平台 | DeepInfra | `https://api.deepinfra.com/v1/openai` | 401；模型列表需显式 `/openai/models` |
| 聚合平台 | Baseten | `https://inference.baseten.co/v1` | 403/网络握手异常，需真实验证 |
| 聚合平台 | Vercel AI Gateway | `https://ai-gateway.vercel.sh/v1` | 401 |
| 国际官方 | Mistral | `https://api.mistral.ai/v1` | 401 |
| 国际平台 | Together AI | `https://api.together.xyz/v1` | 401 |
| 国际平台 | Fireworks AI | `https://api.fireworks.ai/inference/v1` | 401 |
| 国际平台 | Cerebras | `https://api.cerebras.ai/v1` | 401 |
| 国际平台 | Hyperbolic | `https://api.hyperbolic.xyz/v1` | 401 |
| 云平台 | DigitalOcean Gradient | `https://inference.do-ai.run/v1` | 401 |
| 国际官方 | xAI | `https://api.x.ai/v1` | 400，路由存在 |
| 国际官方 | Google Gemini OpenAI 兼容 | `https://generativelanguage.googleapis.com/v1beta/openai` | 400；模型列表需显式 `/models` |
| 国际平台 | Groq | `https://api.groq.com/openai/v1` | 401 |
| 本地服务 | vLLM | `http://localhost:8000/v1` | 需本地实例；允许空 Key |
| 本地服务 | llama.cpp | `http://localhost:8080/v1` | 需本地实例；允许空 Key |
| 本地服务 | LM Studio | `http://localhost:1234/v1` | 需本地实例；允许空 Key |

以下渠道暂不纳入：

- Anthropic Claude 官方 API：原生 Messages 协议，不是 OpenAI Chat Completions；
- OpenAI Responses 专用中转：当前 Agent 只实现 Chat Completions；
- AWS Bedrock、Azure OpenAI、Vertex AI 原生管理面：鉴权、模型发现和请求协议都不同；
- 大量第三方 Coding Plan、Claude Code 中转和赞助渠道：生命周期与信任边界不稳定，
  不应作为默认内置目录；需要时由用户通过“自定义”接入。

### 6.3 火山方舟的特殊说明

火山方舟至少存在三类不同入口：

- 普通按量调用：`https://ark.cn-beijing.volces.com/api/v3`
- Coding Plan：`https://ark.cn-beijing.volces.com/api/coding/v3`
- Agent Plan：`https://ark.cn-beijing.volces.com/api/plan/v3`

当前只内置普通按量入口。Coding/Agent Plan 是否接受与普通 API 相同的模型枚举和
Chat Completions 请求，需要用对应套餐的真实 Key 单独验收后再成为独立预设，不能
把三个地址合并成一个“火山方舟”渠道。

模型字段同时保留模型 ID 与 Endpoint ID 的原始字符串，不在客户端校验格式或做前缀
推断。用户从列表选择或手动粘贴什么值，就原样发送。

## 7. 模型发现协议

### 7.1 请求

模型发现实现位于 `lib/app/ai/ai_model_catalog.dart`：

```dart
Future<List<AiModelInfo>> fetchAiModels({
  required AiSettings settings,
  required AiProviderPreset provider,
});
```

请求规则：

- 支持 `https` 与 `http`；公网明文 HTTP 在保存和请求前要求用户确认；
- 默认超时 15 秒；
- `Accept: application/json`；
- API Key 非空时发送 `Authorization: Bearer <key>`；
- API Key 为空时不发送 `Authorization`，不伪造占位 Key；
- 不发送任何账目数据、聊天内容或应用内日志；
- 保存或请求公网明文 HTTP 前复用 `confirmCleartextIfRisky`；本机/内网地址不告警；
- 重定向只允许同源；跨域重定向直接报错，避免 API Key 被带到另一个主机；
- 响应体上限 5 MB，模型条数上限 2000，超出即失败并提示手动填写；
- 同一时刻只允许一个模型列表请求；切换渠道或修改 URL 后，旧响应必须丢弃。

模型列表只用于当前选择弹层，不写入 KV。远端模型频繁变化，持久化缓存容易让用户
选择已下线模型；如后续需要缓存，必须按渠道、endpoint、模型列表 URL 建键，且不得
保存 API Key。

Android 上的“本机服务”要区分：

- 手机本身运行服务：`localhost` 指向手机；
- 模拟器访问电脑上的服务：通常使用 `10.0.2.2`；
- 手机访问电脑/局域网服务：填写电脑局域网 IP；
- 如目标 Android 版本启用本地网络访问控制，需在真机验收时同步检查权限与拒绝行为。

### 7.2 URL 解析

1. 如果预设/自定义配置提供 `modelListUrl`，只使用该精确 URL；
2. 否则 Base URL 以 `/v{N}` 结尾时请求 `{base}/models`；
3. 否则请求 `{base}/v1/models`。

必须显式覆盖模型列表 URL 的已知例子：

- Gemini：`https://generativelanguage.googleapis.com/v1beta/openai/models`
- DeepInfra：`https://api.deepinfra.com/v1/openai/models`
- 火山 Coding/Agent Plan：在真实 Key 验收前标记为手动模型

### 7.3 响应解析

支持：

```json
{"data":[{"id":"model-a","owned_by":"vendor-a"}]}
```

```json
{"models":[{"slug":"model-a"}]}
```

```json
{"models":[{"id":"model-a"}]}
```

要求：

- `data` 优先；`data` 存在但为空时返回空列表，不转去解析另一个字段；
- `models` 可以是任意形状；只提取数组对象的 `slug` 或 `id`；
- 跳过空字符串、数字 ID、缺少稳定 ID 的条目；
- 去重后按 `id` 不区分大小写排序；
- `owned_by` 缺失时使用模型 ID 中 `/` 前的厂商前缀；两者都无法推导时才归入“其他”；
- 不要求响应带 `object`、`created`、价格、上下文长度等字段。

模型项展示：

```dart
class AiModelInfo {
  const AiModelInfo({required this.id, this.ownedBy});
  final String id;
  final String? ownedBy;
}
```

### 7.4 错误映射

沿用 AI 错误的“稳定错误码 + 用户可见本地化文案”原则：

- 401/403：API Key 无效或无权访问；
- 404/405：该渠道没有模型列表接口，请手动填写；
- 429：请求过于频繁或额度不足；
- 超时/网络/TLS：沿用现有 AI 网络错误；
- JSON/字段错误：无法解析模型列表；
- 空列表：连接成功，但当前 Key 没有可用模型；
- URL 非法或跨域重定向：模型列表地址无效。

原始响应体、API Key、Authorization Header 不得写入 UI 或日志；日志只记录渠道 ID、
host、状态码和稳定错误码。

## 8. 设置页交互

### 8.1 页面结构

AI 设置页顶部增加“渠道”卡/行：

```text
[Logo] 当前渠道
       DeepSeek · 官方 OpenAI 兼容接口
                              [更换 >]
```

页面不放大段功能说明，也不在底部重复“AI 为可选功能”的告知。渠道卡下方的连接
配置使用不透明实色填充 + 可见描边的输入框；预设 Base URL 仍只读并显示锁图标，
API Key 与模型可编辑。工具调用协议同样以只读输入框呈现，收起时只显示当前选项
名称；点击输入框后仍由 `AnchoredMenuChoice` 展开带说明的选项菜单。

点击后打开 `showAiProviderPickerSheet`。其中：

- 搜索框固定顶部；
- 横向分组：全部 / 国内官方 / 国际官方 / 聚合平台 / 本地服务 / 自定义；
- 宫格 `maxCrossAxisExtent ≈ 120`、`mainAxisExtent ≈ 112`，Logo 32–36dp；
- 每项显示 Logo、品牌名、最多两行短描述；
- 选中项使用主色细边框和勾选标记；
- 搜索时忽略当前分组，跨全部渠道匹配名称、说明、别名和域名；
- 搜索结果使用列表，显示 Logo、名称、完整说明、分组；
- 无结果使用现有 `EmptyState`。

选择器只返回渠道 ID，不直接写 Controller/KV。

### 8.2 切换渠道

渠道切换在确认后立即写入并自动保存：

- 写入该渠道固定的 Base URL 与模型列表规则，工具调用协议恢复为自动；
- 模型字段保持为空，不预填任何官方建议模型；
- 渠道 ID 变化时清空上一渠道的 API Key 与模型，避免把 A 厂商 Key 发给 B 厂商；
- 同一品牌的不同地区变体也视为不同身份，按新渠道处理；
- 已配置渠道时先弹出确认；取消确认则保持原配置，确认后才清空并保存；
- 确认后立即把渠道 ID、Base URL、Key、模型和协议一起写入设备偏好。

以上清空规则已确认。预设渠道的 Base URL 对所有预设渠道一律只读，仅展示给用户；
用户如需其他地址，必须选择“自定义 OpenAI 兼容”再填写 Base URL。自定义渠道如需
非标准模型列表路径，再展开“模型列表地址（可选）”。

### 8.3 模型字段

模型使用 `TextField + suffixIcon`：

- 右侧图标为向下箭头 `Icons.expand_more`；
- 多渠道/模型多时改为 `Icons.arrow_drop_down` 的同一语义图标，不新增两套入口；
- 点击时校验渠道、Base URL 和模型列表能力；API Key 为空也照常发起无鉴权请求，
  由渠道返回 401/403 等真实结果；
- 请求期间图标替换为 16dp 进度环，重复点击被忽略；
- 成功后打开模型选择弹层；
- 失败后不关闭设置页、不清空已填模型，通过根级 Feedback Host 提示；
- 模型输入框始终可编辑，列表只是辅助选择。

获取模型时使用页面当前编辑值，而不是上次已保存的配置；用户修改 Key 后无需先保存
即可验证该 Key。请求结果回填输入框后按文本防抖自动保存。

模型选择弹层：

- 使用 `showVeriModalSheet` 统一 chrome；
- 顶部搜索模型 ID、显示名、`owned_by` 或模型 ID 推导出的厂商；
- 按 `owned_by` 分组；缺失时用模型 ID 中 `/` 前的厂商前缀，仍无法推导才归入“其他”；
- 行高至少 44dp，显示模型 ID，右侧显示所属厂商或当前选中标记；
- 模型多时使用懒列表，不一次性构建全部行；
- 点击行返回模型 ID 并关闭弹层；取消返回 `null`。

### 8.4 模型输入与保存

不把“列表第一项”自动当成默认模型：聚合平台第一项可能是图像、嵌入或非对话模型。

模型策略：

- 渠道预设不携带默认模型，不在代码或 KV 中写入会过期的模型 ID；
- 用户在模型弹层中选择，或直接手动填写；
- 模型可以留空，不阻塞页面自动保存；后续请求会按配置实际值失败并提示；
- 远端模型列表失败不影响手动输入和自动保存；
- 所有渠道字段沿用设置页自动保存语义，不再有页面级保存按钮。

## 9. Logo 与视觉

### 9.1 资源目录

新增：

```text
assets/ai_providers/
  openai.svg
  deepseek.svg
  huoshan.png
  kimi.svg
  zhipu.svg
  qianwenai.svg
  openrouter.svg
  ollama.svg
  NOTICE.md
```

`pubspec.yaml` 增加目录资源声明。继续使用项目已有的 `flutter_svg`，不新增图片或
图标依赖。

### 9.2 渲染

新增 `AiProviderLogo`：

- 32–36dp，固定正方形；
- 中性实色底 + 细描边，避免透明黑色 Logo 在深色背景上消失；
- 12% 内边距；
- 不按主题色重绘品牌 Logo；
- 未知或缺失资源回退到通用的 hub 网关图标；
- 不通过网络加载 Logo。

### 9.3 素材来源

当前 8 个预设使用 `openai`、`deepseek`、`huoshan`、`kimi`、`zhipu`、
`qianwenai`、`openrouter`、`ollama` 素材，均从 cc-switch 的
`src/icons/extracted/` 提取，并在 `assets/ai_providers/NOTICE.md` 记录源文件与
上游项目。

缺失素材时：

1. 优先寻找对应厂商的官方品牌资产；
2. 仍缺失则使用中性的渠道首字母/网关图标；
3. 不临时抓取远程 Logo，不把非官方二次创作 Logo 混入目录。

### 9.4 许可证落地

实际复制素材时新增 `assets/ai_providers/NOTICE.md` 或等价说明，至少包含：

- 素材来源：`farion1231/cc-switch` 与本项目引用的 `lobehub/lobe-icons`；
- 各自 MIT 许可证文本；
- 本次取的提交哈希；
- 商标归各厂商所有，仅用于渠道识别；
- 不对 Logo 做改动。

## 10. 测试与验收

### 10.1 纯函数测试

- 渠道 ID 唯一、非空、不可重复；
- 每个预设的 URL 合法，且不以 `/chat/completions` 结尾；
- 精确模型列表 URL 优先于通用推导；
- `/v1`、`/v4`、非版本路径、尾斜杠、完整 URL 的模型列表推导；
- `data[].id`、`models[].slug`、`models[].id` 三种响应；
- `data` 与无关 `models` 共存时仍解析 `data`；
- 空 ID、数字 ID、重复 ID、缺失 `owned_by` 时用 ID 前缀分组、超大条目；
- 401/403、404/405、429、超时、非 JSON、空列表的错误映射；
- 密钥、Authorization、响应体不进日志。

### 10.2 本地 HttpServer 测试

使用 `dart:io HttpServer`，不访问真实公网：

- 200 且返回标准列表；
- 200 且返回 `models[].slug`；
- API Key 为空时不发送 `Authorization`，且可用于公开列表；
- API Key 为空时聊天请求同样不发送 `Authorization`；
- 401；
- 404/405；
- 429；
- 超时；
- 非 JSON；
- 同源重定向成功；
- 跨域重定向被拒绝；
- 无鉴权本地服务不发送 Authorization；
- 请求体为空，确认没有账目数据。

### 10.3 Widget 测试

- 旧配置显示为自定义渠道且 Key/模型不丢；
- 打开渠道选择器、分组筛选、搜索、选中；
- 搜索跨分组；
- 无结果空态；
- 手动输入 Base URL 与模型；
- 模型下拉请求中、成功、失败三种状态；
- 成功后弹层展示模型并按 `owned_by` 或模型 ID 的厂商前缀分组；
- 选中模型回填输入框；
- 切换渠道清空旧 Key/模型；已配置时需确认，取消确认后原配置不变；
- 自动保存后持久化，重启恢复；
- 模型列表失败仍可手填并自动保存；
- 未知渠道 ID 回退自定义且不崩溃；
- 360dp、393×852、浅色、深色、大字号不溢出；
- 宫格与列表选择项具备读屏 label、selected 语义和稳定 key。

### 10.4 真机验收

至少用真实 Key、公开模型列表或用户提供的本地服务验收：

- DeepSeek；
- 火山方舟普通按量入口；
- 一个非标准模型列表 URL 渠道（Gemini 或 DeepInfra）；
- 一个公开模型列表渠道（OpenRouter/ModelScope）；
- Ollama 或 LM Studio；
- 自定义 OpenAI 兼容网关。

每项检查：

- 获取模型成功；
- 所选模型能完成普通对话；
- 能进入“检测能力”；
- Tool Calls 或兼容模式至少一种可用；
- 重启后配置保留；
- 配置不进入备份；
- 不泄露 Key 或原始响应。

## 11. 实现落点

- 渠道注册表与模型列表地址规则：
  `lib/app/ai/ai_provider_presets.dart`
- 渠道说明、分组与搜索匹配：
  `lib/app/ai/ai_provider_presentation.dart`
- 模型发现、响应解析与错误映射：
  `lib/app/ai/ai_model_catalog.dart`
- 渠道宫格与模型选择弹层：
  `lib/pages/ai_provider_picker.dart`、`lib/pages/ai_model_picker.dart`
- Logo 托盘与离线素材：
  `lib/pages/ai_provider_logo.dart`、`assets/ai_providers/`
- 设置页自动保存、只读 Base URL、空 Key 保存和模型获取：
  `lib/pages/ai_settings_page.dart`
- 稳定弹层入口：
  `lib/pages/sheets.dart`
- 配置字段与旧配置兼容：
  `lib/app/ai/ai_settings.dart`

## 12. 参考

- cc-switch 仓库：<https://github.com/farion1231/cc-switch>
  - 调研提交：`77c6dc793d4fbc13bc96163d55d747b02f887a8b`
  - MIT License
- DeepSeek 模型列表：
  <https://api-docs.deepseek.com/api/list-models>
- 火山方舟文档入口：<https://www.volcengine.com/docs/82379/1099455>
- Lobe Icons：<https://github.com/lobehub/lobe-icons>（MIT）
- OpenAI-compatible 模型列表响应与工具调用协议，以各渠道当前官方文档和本地
  HttpServer 测试为准；本文的 401/403/400/200 记录只用于调研阶段的端点分类。
