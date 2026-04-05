### T-013: 实现配置管理系统
**状态**: completed
**优先级**: P2
**创建**: 2026-04-05
**完成**: 2026-04-05
**预计耗时**: 2h
**实际耗时**: 1.5h

**描述**:
实现完整的配置管理，支持配置文件、环境变量、API Key 管理。

**文件**:
- `src/utils/config.zig` - 配置管理实现
- `src/cli/root.zig` - CLI config 命令

**已实现功能**:
- [x] Config 结构体定义
- [x] ConfigManager 实现
- [x] 配置文件读取/写入 (JSON)
- [x] 默认配置路径 `~/.kimiz/config.json`
- [x] API Key 管理（内存中）
- [x] 主题/显示设置
- [x] **CLI config 子命令实现** - get/set/list/apikey 命令

**CLI 命令**:
```bash
kimiz config                    # 显示当前配置
kimiz config get <key>          # 获取配置项
kimiz config set <key> <value>  # 设置配置项
kimiz config list               # 列出所有配置
kimiz config apikey <provider> <key>  # 设置 API key
```

**验收标准**:
- [x] 配置文件读取/写入 ✅
- [x] 默认配置路径 `~/.kimiz/config.json` ✅
- [x] CLI config 子命令实现 ✅
- [x] API Key 管理 ✅
- [x] 主题/显示设置 ✅

**依赖**: 

**笔记**:
配置管理已完成，支持：
- JSON 配置文件持久化
- 完整的 CLI 配置命令
- API Key 管理（当前明文存储，未来可加密）

