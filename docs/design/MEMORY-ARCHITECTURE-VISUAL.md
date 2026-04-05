# Memory Architecture: Letta vs Kimiz (Visual Comparison)

## 1. Core Philosophy

### Letta: "Memory is the OS"
```
┌─────────────────────────────────────────────────────────────┐
│                    LETTA AGENT                              │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  User Input                                                  │
│      ↓                                                       │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ MEMORY LAYER (Operating System)                      │  │
│  │ • Manages what LLM sees                              │  │
│  │ • Controls identity and behavior                     │  │
│  │ • Enables learning through context rewriting         │  │
│  └──────────────────────────────────────────────────────┘  │
│      ↓                                                       │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ LLM INFERENCE                                        │  │
│  │ • Receives curated context                           │  │
│  │ • Generates response                                 │  │
│  │ • Calls tools                                        │  │
│  └──────────────────────────────────────────────────────┘  │
│      ↓                                                       │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ TOOL EXECUTION                                       │  │
│  │ • Bash, file operations, memory tools                │  │
│  │ • Updates memory (git-backed)                        │  │
│  └──────────────────────────────────────────────────────┘  │
│      ↓                                                       │
│  Result                                                      │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Kimiz: "Skills are the Unit of Capability"
```
┌─────────────────────────────────────────────────────────────┐
│                    KIMIZ AGENT                              │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  User Request                                               │
│      ↓                                                       │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ SKILL SELECTION LAYER                               │  │
│  │ • Which skill to use?                               │  │
│  │ • Which model to use?                               │  │
│  │ • Adaptive routing based on learning                │  │
│  └──────────────────────────────────────────────────────┘  │
│      ↓                                                       │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ EXECUTION PLAN                                       │  │
│  │ • Skill-specific workflow                            │  │
│  │ • Tool orchestration                                 │  │
│  │ • Context assembly                                   │  │
│  └──────────────────────────────────────────────────────┘  │
│      ↓                                                       │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ LLM INFERENCE                                        │  │
│  │ • Receives skill context                             │  │
│  │ • Generates response                                 │  │
│  │ • Calls tools                                        │  │
│  └──────────────────────────────────────────────────────┘  │
│      ↓                                                       │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ LEARNING ENGINE                                      │  │
│  │ • Track success/failure                              │  │
│  │ • Update model performance                           │  │
│  │ • Improve skill selection                            │  │
│  └──────────────────────────────────────────────────────┘  │
│      ↓                                                       │
│  Result                                                      │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Memory Structure Comparison

### Letta: Core/Recall/Archival (Access Pattern Based)

```
┌─────────────────────────────────────────────────────────────┐
│ CORE MEMORY (RAM-like)                                      │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ Always loaded in context window                         │ │
│ │ • persona.md (identity, safety)                         │ │
│ │ • human.md (user facts, preferences)                    │ │
│ │ • custom_blocks/ (team norms, constraints)              │ │
│ │                                                         │ │
│ │ Size: 1-2KB (small, hot, fast)                          │ │
│ │ Cost: High (always in context)                          │ │
│ │ Access: Instant                                         │ │
│ └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ RECALL MEMORY (Cache-like)                                  │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ Semantic/date-indexed retrieval                         │ │
│ │ • Conversation history (indexed)                        │ │
│ │ • Recent interactions (cached)                          │ │
│ │ • Insights from past sessions                           │ │
│ │                                                         │ │
│ │ Size: Medium (selective)                                │ │
│ │ Cost: Medium (loaded on demand)                         │ │
│ │ Access: Fast (indexed search)                           │ │
│ └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ ARCHIVAL MEMORY (Disk-like)                                 │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ Durable, searchable storage                             │ │
│ │ • Documents, knowledge bases                            │ │
│ │ • Long-term facts and relationships                     │ │
│ │ • Historical artifacts and traces                       │ │
│ │                                                         │ │
│ │ Size: Large (unlimited)                                 │ │
│ │ Cost: Low (rarely in context)                           │ │
│ │ Access: Slower (full-text search)                       │ │
│ └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### Kimiz: Short/Working/Long-term (Scope Based)

```
┌─────────────────────────────────────────────────────────────┐
│ SHORT-TERM MEMORY (Session)                                 │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ Current interaction context                             │ │
│ │ • Active conversation                                   │ │
│ │ • Recent code changes                                   │ │
│ │ • Current task state                                    │ │
│ │                                                         │ │
│ │ Scope: Single interaction                               │ │
│ │ Lifetime: Session duration                              │ │
│ │ Access: Instant (in-memory)                             │ │
│ └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ WORKING MEMORY (Project)                                    │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ Project-level patterns and context                      │ │
│ │ • Tech stack detection                                  │ │
│ │ • Code patterns & conventions                           │ │
│ │ • Important files & dependencies                        │ │
│ │                                                         │ │
│ │ Scope: Single project/codebase                          │ │
│ │ Lifetime: Project-scoped                                │ │
│ │ Access: Query-based (database)                          │ │
│ └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ LONG-TERM MEMORY (User)                                     │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ User-level preferences and history                      │ │
│ │ • Coding style preferences                              │ │
│ │ • Frequently used tools                                 │ │
│ │ • Model performance history                             │ │
│ │                                                         │ │
│ │ Scope: Cross-project, user-level                        │ │
│ │ Lifetime: Persistent                                    │ │
│ │ Access: Query-based (database)                          │ │
│ └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

---

## 3. Storage & Persistence

### Letta: Git-Backed Memory Filesystem (MemFS)

```
Agent Memory (in-context)
    ↓
┌─────────────────────────────────────────────────────────────┐
│ MemFS (Local Filesystem Projection)                         │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│ ~/.letta/agents/{agent_id}/                                 │
│ ├── .git/                    # Git repository               │
│ │   ├── objects/             # Git objects                  │
│ │   ├── refs/                # Branch references            │
│ │   └── HEAD                 # Current branch               │
│ │                                                           │
│ ├── system/                  # In-context memory            │
│ │   ├── persona.md           # Identity (always loaded)     │
│ │   ├── human.md             # User facts (always loaded)   │
│ │   └── custom_blocks/       # Custom memory blocks         │
│ │                                                           │
│ ├── skills/                  # Agent-owned skills           │
│ │   ├── code_review/         # Skill library                │
│ │   ├── refactoring/         # Skill library                │
│ │   └── SKILL.md             # Skill metadata               │
│ │                                                           │
│ ├── reference/               # External memory              │
│ │   ├── api_docs.md          # Load on demand               │
│ │   ├── code_patterns.md     # Load on demand               │
│ │   └── user_feedback.md     # Load on demand               │
│ │                                                           │
│ └── .gitignore               # Git ignore rules             │
│                                                              │
└─────────────────────────────────────────────────────────────┘
    ↓
Git Versioning (every change tracked)
    ↓
Remote Sync (push/pull for persistence)
```

**Key Features**:
- ✅ Filesystem primitives (bash, scripts, standard tools)
- ✅ Git versioning (full audit trail)
- ✅ Concurrent writes (git worktrees for subagents)
- ✅ Progressive disclosure (filetree structure)
- ✅ Frontmatter metadata (YAML headers)

### Kimiz: Persistent Store (TBD)

```
Agent Memory (in-memory during session)
    ↓
┌─────────────────────────────────────────────────────────────┐
│ Persistent Store (SQLite or Postgres)                       │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│ interactions table                                           │
│ ├── id, agent_id, timestamp                                 │
│ ├── user_message, assistant_response                        │
│ ├── skill_used, model_used                                  │
│ └── success, feedback                                       │
│                                                              │
│ skills table                                                │
│ ├── id, agent_id, skill_name                                │
│ ├── success_count, failure_count                            │
│ └── last_used                                               │
│                                                              │
│ user_preferences table                                      │
│ ├── id, agent_id, key, value                                │
│ └── updated_at                                              │
│                                                              │
│ model_performance table                                     │
│ ├── id, agent_id, model_name                                │
│ ├── avg_latency, success_rate                               │
│ └── last_used                                               │
│                                                              │
│ code_patterns table                                         │
│ ├── id, agent_id, pattern_name                              │
│ ├── pattern_data, frequency                                 │
│ └── last_seen                                               │
│                                                              │
└─────────────────────────────────────────────────────────────┘
    ↓
Learning Engine (updates on each interaction)
```

**Characteristics**:
- ⚠️ Session-scoped state (memory persists across restarts)
- ⚠️ Structured data (relational, not filesystem)
- ⚠️ Automatic updates (learning engine decides)
- ⚠️ Query-based retrieval (SQL queries)
- ⚠️ No explicit versioning (likely append-only logs)

---

## 4. Learning Mechanisms

### Letta: Token-Space Continual Learning

```
Experience
    ↓
┌─────────────────────────────────────────────────────────────┐
│ Agent interacts with user, gets feedback                    │
└─────────────────────────────────────────────────────────────┘
    ↓
Reflection (Sleep-Time Agent)
    ↓
┌─────────────────────────────────────────────────────────────┐
│ Sleep-time agent reviews conversation                       │
│ • Identifies patterns                                       │
│ • Extracts insights                                         │
│ • Finds learnings                                           │
└─────────────────────────────────────────────────────────────┘
    ↓
Consolidation
    ↓
┌─────────────────────────────────────────────────────────────┐
│ Update system prompt, memory blocks                         │
│ • Rewrite persona.md                                        │
│ • Update human.md                                           │
│ • Add learned patterns                                      │
└─────────────────────────────────────────────────────────────┘
    ↓
Verification
    ↓
┌─────────────────────────────────────────────────────────────┐
│ Test new context on similar tasks                           │
│ • Does it improve performance?                              │
│ • Does it maintain identity?                                │
│ • Does it generalize?                                       │
└─────────────────────────────────────────────────────────────┘
    ↓
Commit (Git)
    ↓
┌─────────────────────────────────────────────────────────────┐
│ Version the change with git                                 │
│ • Commit message: "Learn: improved error handling"          │
│ • Full audit trail                                          │
│ • Can be reverted if needed                                 │
└─────────────────────────────────────────────────────────────┘
```

**Learning Targets**:
- System prompt (identity, behavioral guidelines)
- Memory blocks (facts, preferences, patterns)
- Skill organization (which skills to load when)
- Context structure (how to organize information)

### Kimiz: Adaptive Learning Engine

```
Observation
    ↓
┌─────────────────────────────────────────────────────────────┐
│ Track outcomes                                              │
│ • Tool success/failure                                      │
│ • Model performance (latency, quality, cost)                │
│ • Skill effectiveness                                       │
│ • User feedback                                             │
└─────────────────────────────────────────────────────────────┘
    ↓
Analysis
    ↓
┌─────────────────────────────────────────────────────────────┐
│ Identify patterns                                           │
│ • Which models work best?                                   │
│ • Which skills succeed?                                     │
│ • What are user preferences?                                │
│ • What are code patterns?                                   │
└─────────────────────────────────────────────────────────────┘
    ↓
Adaptation
    ↓
┌─────────────────────────────────────────────────────────────┐
│ Update decision-making                                      │
│ • Improve skill selection                                   │
│ • Optimize model routing                                    │
│ • Refine tool usage                                         │
│ • Adapt to user style                                       │
└─────────────────────────────────────────────────────────────┘
    ↓
Persistence
    ↓
┌─────────────────────────────────────────────────────────────┐
│ Store learnings in memory                                   │
│ • Update model_performance table                            │
│ • Update skills table                                       │
│ • Update user_preferences table                             │
│ • Update code_patterns table                                │
└─────────────────────────────────────────────────────────────┘
```

**Learning Targets**:
- Model performance (which models work best)
- Skill effectiveness (which skills succeed)
- Tool usage (which tools are most useful)
- User preferences (coding style, patterns)
- Code patterns (project-specific conventions)

---

## 5. Agent Harness Comparison

### Letta Code: Memory-First Harness

```
┌─────────────────────────────────────────────────────────────┐
│                  LETTA CODE HARNESS                         │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ MemFS (Git-backed Memory Filesystem)                 │  │
│  │ ├── /system/        (in-context memory)              │  │
│  │ ├── /skills/        (agent-owned skills)             │  │
│  │ └── /reference/     (external memory)                │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ Agent Loop                                           │  │
│  │ ├── Context Compiler (assembles context window)      │  │
│  │ ├── LLM Inference (with current context)             │  │
│  │ ├── Tool Execution (bash, file ops, etc.)            │  │
│  │ └── Memory Management (update MemFS)                 │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ Sleep-Time Compute                                   │  │
│  │ ├── Primary Agent (user interaction, fast model)     │  │
│  │ └── Sleep-Time Agent (memory consolidation, strong)  │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ Subagents                                            │  │
│  │ ├── Recall (search conversations)                    │  │
│  │ ├── Reflection (review & update memory)              │  │
│  │ └── Defragmentation (reorganize memory)              │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Kimiz: Skill-First Harness

```
┌─────────────────────────────────────────────────────────────┐
│                   KIMIZ HARNESS                             │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ Skill System                                         │  │
│  │ ├── Code Review                                      │  │
│  │ ├── Refactoring                                      │  │
│  │ ├── Test Generation                                  │  │
│  │ ├── Documentation                                    │  │
│  │ └── Debugging                                        │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ Agent Loop                                           │  │
│  │ ├── Skill Selection (which skill to use)             │  │
│  │ ├── Execution Plan (how to execute)                  │  │
│  │ ├── Tool Orchestration (file, search, bash, web)     │  │
│  │ └── Result Aggregation                               │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ Memory System                                        │  │
│  │ ├── Short-Term (session context)                     │  │
│  │ ├── Working (project-level patterns)                 │  │
│  │ └── Long-Term (user preferences)                     │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ Learning Engine                                      │  │
│  │ ├── Model Performance Tracking                       │  │
│  │ ├── Skill Effectiveness Analysis                     │  │
│  │ ├── Adaptive Routing                                 │  │
│  │ └── Pattern Recognition                              │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ Multi-Provider Support                               │  │
│  │ ├── OpenAI (GPT-4o, o1, o3)                          │  │
│  │ ├── Anthropic (Claude 3.5 Sonnet)                    │  │
│  │ ├── Google (Gemini 2.0 Flash)                        │  │
│  │ ├── Kimi (k1, Moonshot)                              │  │
│  │ └── Fireworks (Open source)                          │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 6. Recommended Hybrid Architecture

### Combining Letta's Memory with Kimiz's Skills

```
┌─────────────────────────────────────────────────────────────┐
│              HYBRID ARCHITECTURE (RECOMMENDED)              │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  User Request                                               │
│      ↓                                                       │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ SKILL SELECTION LAYER (Kimiz)                        │  │
│  │ • Which skill to use?                                │  │
│  │ • Which model to use?                                │  │
│  │ • Adaptive routing based on learning                 │  │
│  └──────────────────────────────────────────────────────┘  │
│      ↓                                                       │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ MEMORY LAYER (Letta)                                 │  │
│  │ • Assemble context from MemFS                        │  │
│  │ • Core memory (always loaded)                        │  │
│  │ • Recall memory (semantic search)                    │  │
│  │ • Archival memory (on demand)                        │  │
│  └──────────────────────────────────────────────────────┘  │
│      ↓                                                       │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ LLM INFERENCE                                        │  │
│  │ • Receives curated context                           │  │
│  │ • Generates response                                 │  │
│  │ • Calls tools                                        │  │
│  └──────────────────────────────────────────────────────┘  │
│      ↓                                                       │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ TOOL EXECUTION                                       │  │
│  │ • Bash, file operations, memory tools                │  │
│  │ • Updates memory (git-backed)                        │  │
│  └──────────────────────────────────────────────────────┘  │
│      ↓                                                       │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ LEARNING ENGINE (Both)                               │  │
│  │ • Token-space learning (Letta)                       │  │
│  │ • Adaptive optimization (Kimiz)                      │  │
│  │ • Update MemFS (git commit)                          │  │
│  │ • Update performance metrics                         │  │
│  └──────────────────────────────────────────────────────┘  │
│      ↓                                                       │
│  Result                                                      │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

**Benefits**:
- ✅ Practical execution (skills are intuitive)
- ✅ Powerful learning (memory is infrastructure)
- ✅ Auditable changes (git versioning)
- ✅ Explicit control (agents manage their own context)
- ✅ Adaptive optimization (learning engine)
- ✅ Native performance (Zig)

