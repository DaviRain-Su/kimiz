# OpenWallet Standard (OWS) 分析 — 能否用来做你的 AI 付费系统？

**分析对象**: [OpenWallet Standard (OWS)](https://docs.openwallet.sh)  
**分析日期**: 2026-04-05  

**核心结论**:
- **OWS 不能直接用在你的产品里做 "登录 + 充值 + 结算" 系统。**
- 原因很简单：**OWS 不支持 Tezos/Temple 钱包**，而且它的核心定位是**本地 Agent 钱包管理工具**，不是**面向用户的服务平台**。
- 但是，OWS 的**策略引擎（Policy Engine）**和 **x402 支付协议**对你的产品有很高的**参考价值**。

---

## 1. OpenWallet Standard 是什么

OWS 是一个**本地钱包管理开源标准**，用 Rust 实现，提供 CLI 和 SDK（Node.js/Python）。

### 核心定位
> "Local, policy-gated signing and wallet management for every chain."

它不是给用户注册网站账号用的，而是给 **AI Agent / CLI 工具** 用的本地钱包管理器。

### 核心能力

| 能力 | 说明 |
|------|------|
| **本地加密存储** | 钱包私钥加密存在 `~/.ows/wallets/` |
| **多链支持** | EVM、Solana、Bitcoin、Cosmos、Tron、TON、Sui、XRPL、Filecoin、Spark |
| **策略引擎** | 签名前强制评估策略（链白名单、过期时间、自定义 executable） |
| **Agent 授权** | 用 API key + policy 给 Agent 受限的签名权限，Agent 永远看不到私钥 |
| **x402 支付** | `ows pay request` 自动处理 402 Payment Required 的服务付费 |
| **MoonPay 入金** | `ows fund deposit` 可以通过 MoonPay 用法币买币充值 |

---

## 2. 为什么 OWS 不适合直接用来做你的产品

### 2.1 ❌ 不支持 Tezos / Temple 钱包

这是最直接的问题。OWS 支持的所有链：
- EVM (Ethereum, Base, Polygon, etc.)
- Solana
- Bitcoin
- Cosmos
- Tron
- TON
- Sui
- XRPL
- Filecoin
- Spark

**没有 Tezos。** 如果你之前已经确定要用 Temple 钱包，OWS 完全无法对接。

### 2.2 ❌ OWS 是 "本地 Agent 工具"，不是 "用户服务平台"

OWS 的设计假设是：
> "一个 AI Agent 运行在你的本地电脑上，需要安全地管理自己的钱包。"

你的产品设计假设是：
> "用户登录一个 Web/APP 平台，往钱包里充钱，然后消费 AI 服务。"

这两个场景**完全不一样**。

#### OWS 的典型使用场景
```
本地电脑上运行的 Claude Code / Cursor Agent
        ↓
   调用 OWS SDK
        ↓
   用本地存储的钱包签名交易
        ↓
   向链上 DEX 下单 / 向 API 付费
```

#### 你的产品的典型使用场景
```
用户打开手机/浏览器
        ↓
   登录你的平台
        ↓
   用 Temple/Stripe 充值
        ↓
   在云端调用 GPT-4 / Claude
        ↓
   按 token 扣费
```

OWS 没有用户认证系统、没有服务端余额管理、没有按 token 计费的能力。

### 2.3 ❌ OWS 的 "充值" 是给自己钱包买币，不是给用户账户加余额

OWS 的 `ows fund deposit` 是通过 **MoonPay** 给**用户自己的本地钱包**买币。买了币之后，币在用户自己的钱包地址里。

你的系统需要的是：
> "用户把钱给你（或存到智能合约），然后你在自己的数据库里给他记一笔余额。"

这是两个完全不同的模型。

### 2.4 ❌ OWS 的 x402 是 "客户端付钱给 API"，不是 "服务端收钱提供服务"

OWS 支持 x402 协议，命令是 `ows pay request`：
```bash
ows pay request "https://api.example.com/data" --wallet agent-treasury
```

这表示 OWS 作为**客户端**，主动向某个支持 x402 的 API **付费**。

而你的产品需要的是**作为服务端**，接受用户的付费请求，然后在验证付费后提供 AI 服务。

x402 协议本身是可以双向支持的，但 OWS 这个实现只做了**客户端侧**。

---

## 3. OWS 有哪些地方值得你的产品学习

虽然不适合直接用，但 OWS 有几个设计非常出色，可以借鉴。

### 3.1 策略引擎（Policy Engine）— 最值得借鉴

OWS 的策略引擎可以在**每次签名前**执行策略检查。这个思路完全可以迁移到你的 "按量付费" 系统中。

#### OWS 的策略模型
```
Agent 发起签名请求
        ↓
   检查 API key 的 policy
        ↓
   声明式规则：链白名单、过期时间
        ↓
   自定义 executable：任意复杂逻辑
        ↓
   全部通过才签名
```

#### 迁移到你的产品："余额策略引擎"
```
用户发起 AI 调用
        ↓
   检查用户的 "余额策略"
        ↓
   规则 1：余额 > 0？
   规则 2：当日消费 < $10？
   规则 3：单次调用 < $0.50？
        ↓
   全部通过才调用 AI 并扣费
```

这本质上就是把 OWS 的 "pre-signing policy" 改成 "pre-spending policy"。

### 3.2 API Key + Policy 的代理授权模型

OWS 允许给 Agent 发一个受限制的 API key，Agent 可以用它来签名，但永远无法拿到私钥。

这个模型对你的产品也很有价值：
- 用户生成一个**受限制的 API key**
- Agent / 第三方工具可以用这个 key 调用你的 AI 服务
- key 绑定策略：每日限额、可用模型、最大 token 数
- 用户随时可以 revoke

这和 OpenAI API key 很像，但加上了一层**策略引擎**。

### 3.3 x402 协议 — 可以作为服务端收费的标准接口

虽然 OWS 只实现了 x402 客户端，但 x402 本身是一个开放的 HTTP 402 付费协议：

1. 客户端请求：`GET /resource`
2. 服务端返回：`402 Payment Required` + `WWW-Authenticate: Payment ...`
3. 客户端签名支付凭证
4. 客户端重试：`GET /resource` + `Authorization: Payment ...`
5. 服务端验证后返回资源

如果你的 AI API 想要支持"机器对机器支付"（比如其他 Agent 调用你的服务），**实现一个 x402 服务端**是非常有前瞻性的。

### 3.4 本地密钥安全模型

OWS 的密钥安全设计非常严谨：
- 私钥**静态加密**（AES-256-GCM）
- 解密只在**签名流程中**进行
- 用完后**立即从内存擦除**
- Agent 用 API token 访问，但 API token 对应的是**重新加密过的密钥副本**

如果你的产品需要托管用户的私钥（比如为了自动扣款），这套安全模型非常值得参考。

---

## 4. 给你的具体建议

### 4.1 放弃 "用 OWS 直接做产品" 的想法

OWS 不是你的答案。它：
- 不支持 Tezos
- 没有用户登录系统
- 没有服务端余额管理
- 没有按 token 计费
- 没有 Web Dashboard

### 4.2 借鉴 OWS 的策略引擎，设计你自己的 "Spending Policy Engine"

可以设计一个轻量级的策略系统，在用户每次调用 AI 前执行：

```json
{
  "id": "user-default-limits",
  "user_id": "u_123",
  "rules": [
    { "type": "balance_positive", "min_balance": "0.10" },
    { "type": "daily_spend_cap", "max_usd": "10.00" },
    { "type": "single_request_cap", "max_usd": "0.50" },
    { "type": "model_allowlist", "models": ["gpt-4o", "claude-3-haiku"] }
  ],
  "action": "deny"
}
```

执行时：
```python
def before_ai_call(user_id, model, estimated_tokens):
    policy = get_policy(user_id)
    context = build_context(user_id, model, estimated_tokens)
    result = evaluate_policy(policy, context)
    if not result.allow:
        raise PolicyDenied(result.reason)
    # 继续调用 AI 并扣费
```

### 4.3 如果你做 AI API 对外输出，考虑实现 x402 服务端

这样其他 Agent（包括使用 OWS 的 Agent）可以直接调用你的服务并自动付费：

```python
from flask import Flask, request, Response

@app.route("/chat")
def chat():
    auth = request.headers.get("Authorization")
    if not verify_payment(auth):
        return Response(
            "Payment Required",
            status=402,
            headers={"WWW-Authenticate": "Payment ..."}
        )
    # 处理 AI 请求
```

### 4.4 关于充值入口的建议

你之前想接入 Temple 钱包。但 OWS 有一个更有趣的能力：**MoonPay 法币入金**。

这进一步验证了我的建议：
> **不要只做 crypto，必须加法币入口。**

OWS 自己的 `ows fund deposit` 就是通过 MoonPay 接的法币通道。这说明即使是 "硬核 Web3 钱包工具"，也逃不掉"普通人需要法币买币"这个现实。

你的产品的充值入口优先级应该是：
1. **Stripe / 支付宝 / 微信**（主入口，覆盖 99% 用户）
2. **MoonPay / Coinbase Commerce**（crypto 新手入口）
3. **Temple / MetaMask 等钱包直连**（资深 Web3 用户入口）

---

## 5. 总结

### OpenWallet 能直接用吗？
**不能。**

### 为什么？
1. 不支持 Tezos / Temple
2. 它是本地 Agent 工具，不是用户服务平台
3. 它的充值是给自己钱包买币，不是平台余额充值
4. 它的 x402 是客户端付钱，不是服务端收钱

### 但它有好的地方可以借鉴吗？
**有，而且非常值得借鉴：**
1. **策略引擎** → 可以改造成 "消费前策略检查"
2. **API Key + Policy** → 可以设计受限的 AI 调用 API key
3. **x402 协议** → 如果要对外提供 AI API，建议实现 x402 服务端
4. **密钥安全模型** → 如果需要托管私钥，参考它的加密和擦除流程

### 一句话建议

> **OWS 不是你的 "登录充值结算系统" 的现成答案。它是一个给本地 AI Agent 用的钱包管理工具。你应该借鉴它的策略引擎和 x402 理念，但结算系统的核心还是得自己搭 — 链下余额 + 多入口充值（法币为主 + crypto 为辅），这才是最务实的路径。**

---

如果你愿意，我可以现在帮你设计一个适合你的 "余额策略引擎" 的 JSON Schema 和核心逻辑代码。要不要？
