### T-013: 实现配置管理系统
**状态**: in_progress
**优先级**: P2
**创建**: 2026-04-05
**预计耗时**: 2h
**实际耗时**: 1h

**描述**:
实现完整的配置管理，支持配置文件、环境变量、API Key 管理。

**文件**:
- `src/utils/config.zig` - 基础实现已完成

**已实现功能**:
- [x] Config 结构体定义
- [x] ConfigManager 实现
- [x] 配置文件读取/写入 (JSON)
- [x] 默认配置路径 `~/.kimiz/config.json`
- [x] API Key 管理（内存中）
- [x] 主题/显示设置

**待完善功能**:
- [ ] CLI config 子命令实现
- [ ] API Key 加密存储
- [ ] 模型偏好设置界面
- [ ] 与 CLI 集成

**验收标准**:
- [x] 配置文件读取/写入
- [x] 默认配置路径 `~/.kimiz/config.json`
- [ ] CLI config 子命令实现
- [ ] API Key 管理（加密存储）
- [ ] 模型偏好设置
- [x] 主题/显示设置

**依赖**: 

**笔记**:
基础代码已完成，CLI config 命令需要实现。
当前 CLI config 命令是空的
