# kimiz Task Management Makefile

.PHONY: help task-create task-start task-block task-unblock task-complete task-approve task-list task-show task-stats

# 默认目标
help:
	@echo "kimiz Task Management"
	@echo ""
	@echo "Available commands:"
	@echo "  make task-create TYPE=<type> TITLE=<title>  - Create new task"
	@echo "  make task-start ID=<id>                     - Start task"
	@echo "  make task-block ID=<id> REASON=<reason>     - Block task"
	@echo "  make task-unblock ID=<id>                   - Unblock task"
	@echo "  make task-complete ID=<id>                  - Complete task"
	@echo "  make task-approve ID=<id>                   - Approve task"
	@echo "  make task-list [STATUS=<status>]            - List tasks"
	@echo "  make task-show ID=<id>                      - Show task details"
	@echo "  make task-stats                             - Show statistics"
	@echo ""
	@echo "Examples:"
	@echo "  make task-create TYPE=feature TITLE='实现 Skill 注册表'"
	@echo "  make task-start ID=T-001"
	@echo "  make task-list STATUS=in_progress"

# 生成任务 ID
TASK_ID := T-$(shell printf "%03d" $(shell expr $(shell ls tasks/active/sprint-01-core/*.md tasks/backlog/*/*.md 2>/dev/null | wc -l) + 1))

# 创建新任务
task-create:
	@if [ -z "$(TITLE)" ]; then \
		echo "Error: TITLE is required"; \
		echo "Usage: make task-create TYPE=feature TITLE='your title'"; \
		exit 1; \
	fi
	@mkdir -p tasks/backlog/$(TYPE)
	@cat > tasks/backlog/$(TYPE)/$(TASK_ID)-$(shell echo '$(TITLE)' | tr ' ' '-' | tr '[:upper:]' '[:lower:]').md << EOF
### $(TASK_ID): $(TITLE)
**状态**: pending
**优先级**: P1
**创建**: $(shell date +%Y-%m-%d)
**预计耗时**: 2h

**描述**:
{任务描述}

**验收标准**:
- [ ] {标准1}
- [ ] {标准2}

**依赖**: 

**笔记**:
EOF
	@echo "Created task: $(TASK_ID)"
	@echo "File: tasks/backlog/$(TYPE)/$(TASK_ID)-$(shell echo '$(TITLE)' | tr ' ' '-' | tr '[:upper:]' '[:lower:]').md"

# 开始任务
task-start:
	@if [ -z "$(ID)" ]; then \
		echo "Error: ID is required"; \
		exit 1; \
	fi
	@find tasks/backlog -name "$(ID)*.md" -exec mv {} tasks/active/sprint-01-core/ \;
	@find tasks/active/sprint-01-core -name "$(ID)*.md" -exec sed -i '' 's/\*\*状态\*\*: .*/\*\*状态\*\*: in_progress/' {} \;
	@find tasks/active/sprint-01-core -name "$(ID)*.md" -exec sed -i '' "s/\*\*开始\*\*: .*/\*\*开始\*\*: $(shell date +%Y-%m-%d)/" {} \;
	@echo "Started task: $(ID)"

# 阻塞任务
task-block:
	@if [ -z "$(ID)" ] || [ -z "$(REASON)" ]; then \
		echo "Error: ID and REASON are required"; \
		exit 1; \
	fi
	@find tasks/active -name "$(ID)*.md" -exec sed -i '' 's/\*\*状态\*\*: .*/\*\*状态\*\*: blocked/' {} \;
	@find tasks/active -name "$(ID)*.md" -exec sed -i '' "/\*\*阻塞记录\*\*:/a\\\n- $(shell date +%Y-%m-%d): $(REASON)" {} \;
	@echo "Blocked task: $(ID) - $(REASON)"

# 解除阻塞
task-unblock:
	@if [ -z "$(ID)" ]; then \
		echo "Error: ID is required"; \
		exit 1; \
	fi
	@find tasks/active -name "$(ID)*.md" -exec sed -i '' 's/\*\*状态\*\*: .*/\*\*状态\*\*: in_progress/' {} \;
	@find tasks/active -name "$(ID)*.md" -exec sed -i '' "/\*\*阻塞记录\*\*:/a\\\n- $(shell date +%Y-%m-%d): 阻塞解除" {} \;
	@echo "Unblocked task: $(ID)"

# 完成任务
task-complete:
	@if [ -z "$(ID)" ]; then \
		echo "Error: ID is required"; \
		exit 1; \
	fi
	@find tasks/active -name "$(ID)*.md" -exec sed -i '' 's/\*\*状态\*\*: .*/\*\*状态\*\*: review/' {} \;
	@find tasks/active -name "$(ID)*.md" -exec sed -i '' "s/\*\*完成\*\*: .*/\*\*完成\*\*: $(shell date +%Y-%m-%d)/" {} \;
	@echo "Completed task: $(ID) (pending review)"

# 批准任务
task-approve:
	@if [ -z "$(ID)" ]; then \
		echo "Error: ID is required"; \
		exit 1; \
	fi
	@mkdir -p tasks/completed/sprint-01-core
	@find tasks/active -name "$(ID)*.md" -exec sed -i '' 's/\*\*状态\*\*: .*/\*\*状态\*\*: done/' {} \;
	@find tasks/active -name "$(ID)*.md" -exec mv {} tasks/completed/sprint-01-core/ \;
	@echo "Approved and archived task: $(ID)"

# 列出任务
task-list:
	@echo "=== Active Tasks ==="
	@find tasks/active -name "T-*.md" -exec basename {} \; | sort
	@echo ""
	@echo "=== Backlog ==="
	@find tasks/backlog -name "T-*.md" -exec basename {} \; | sort
	@echo ""
	@echo "=== Completed ==="
	@find tasks/completed -name "T-*.md" 2>/dev/null | wc -l | xargs echo "Total completed:"

# 显示任务详情
task-show:
	@if [ -z "$(ID)" ]; then \
		echo "Error: ID is required"; \
		exit 1; \
	fi
	@find tasks -name "$(ID)*.md" -exec cat {} \;

# 统计信息
task-stats:
	@echo "=== Task Statistics ==="
	@echo "Active:    $$(find tasks/active -name 'T-*.md' | wc -l)"
	@echo "Backlog:   $$(find tasks/backlog -name 'T-*.md' | wc -l)"
	@echo "Completed: $$(find tasks/completed -name 'T-*.md' 2>/dev/null | wc -l)"
	@echo ""
	@echo "By Status:"
	@echo "  pending:     $$(grep -r 'pending' tasks/active tasks/backlog 2>/dev/null | wc -l)"
	@echo "  in_progress: $$(grep -r 'in_progress' tasks/active 2>/dev/null | wc -l)"
	@echo "  blocked:     $$(grep -r 'blocked' tasks/active 2>/dev/null | wc -l)"
	@echo "  review:      $$(grep -r 'review' tasks/active 2>/dev/null | wc -l)"
	@echo "  done:        $$(grep -r 'done' tasks/completed 2>/dev/null | wc -l)"
