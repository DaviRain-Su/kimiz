# Letta vs Kimiz: Memory Architecture Comparison

**Analysis Date**: April 5, 2026  
**Letta Version**: Latest (Letta Code + Context Constitution)  
**Kimiz Version**: 0.0.0 (Alpha, Zig 0.15.2)

---

## Executive Summary

| Aspect | Letta | Kimiz |
|--------|-------|-------|
| **Memory Model** | Core/Recall/Archival (3-tier) | Short/Working/Long-term (3-tier) |
| **Memory as** | OS-level infrastructure | Agent subsystem |
| **Storage Backend** | Git-versioned filesystem (MemFS) | In-memory + persistent store (TBD) |
| **Learning Mechanism** | Token-space continual learning | Adaptive learning engine |
| **Agent Harness** | Memory-first (memory is core) | Skill-first (skills are core) |
| **Context Management** | Explicit (Constitution-driven) | Implicit (learning-driven) |
| **Deployment** | Server-side + Client-side | Single binary (Zig) |
| **Maturity** | Production (1M+ agents at scale) | Alpha (compilation issues) |

---

## 1. Memory Architecture Comparison

### Letta: Core/Recall/Archival Model

**Metaphor**: RAM/Cache/Disk (Operating System)

```
┌─────────────────────────────────────────────────────────────┐
│ CORE MEMORY (RAM-like, always loaded)                       │
│ • persona block (identity, safety boundaries)               │
│ • human block (user facts, preferences)                     │
│ • custom profile blocks (team norms, constraints)           │
│ Size: Small, hot, fast (1-2KB typical)                      │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ RECALL MEMORY (Cache-like, semantic retrieval)              │
│ • Conversation history (indexed by date/semantic)           │
│ • Recent interactions (fast retrieval)                      │
│ • Cached insights from past sessions                        │
│ Size: Medium, selective, indexed                            │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ ARCHIVAL MEMORY (Disk-like, durable store)                  │
│ • Documents, knowledge bases                                │
│ • Long-term facts and relationships                         │
│ • Historical artifacts and traces                           │
│ Size: Large, slower, searchable                             │
└─────────────────────────────────────────────────────────────┘
```

**Key Characteristics**:
- **Tiered by access pattern**: Not by time, but by frequency/cost
- **Dynamic movement**: Agent actively moves data between tiers
- **Explicit tools**: `memory_insert`, `memory_replace`, `memory_rethink`
- **Git-backed**: Every change versioned with commit messages
- **Progressive disclosure**: Filetree structure guides navigation

### Kimiz: Short/Working/Long-term Model

**Metaphor**: Session/Project/User (Cognitive Layers)

```
┌─────────────────────────────────────────────────────────────┐
│ SHORT-TERM MEMORY (Current Session)                         │
│ • Active conversation context                               │
│ • Recent code changes                                       │
│ • Current task state                                        │
│ Scope: Single interaction                                   │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ WORKING MEMORY (Project-Level)                              │
│ • Tech stack detection                                      │
│ • Code patterns & conventions                               │
│ • Important files & dependencies                            │
│ Scope: Single project/codebase                              │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ LONG-TERM MEMORY (User Preferences)                         │
│ • Coding style preferences                                  │
│ • Frequently used tools                                     │
│ • Model performance history                                 │
│ Scope: Cross-project, user-level                            │
└─────────────────────────────────────────────────────────────┘
```

**Key Characteristics**:
- **Tiered by scope**: Session → Project → User
- **Implicit management**: Learning engine decides what to store
- **Adaptive learning**: Tracks success rates, model performance
- **Skill-centric**: Memory supports skill selection/optimization
- **Persistent store**: Backend TBD (likely SQLite/Postgres)

---

## 2. Core Design Philosophy Differences

### Letta: "Memory as Operating System"

**Core Insight**: Memory is not a feature—it's the execution environment.

```
User Input → [Context Compiler] → Agent LLM + Tools → DB + Retrieval
                    ↓
            Memory is the OS layer
            (manages what LLM sees)
```

**Principles** (from Context Constitution):
1. **Context determines identity**: What you put in context = who you are
2. **Context is scarce**: Every token costs; must be managed actively
3. **Token-space learning**: Learn by rewriting your own context
4. **Continuity across models**: Memory survives model changes
5. **Experiential AI**: Learn from lived experience, not just training

**Sarah Wooders' Statement**: "Memory is core to Agent Harness, not a plugin"
- Memory is **not** a tool you call
- Memory is **not** a database you query
- Memory is **the harness itself**—the infrastructure that enables agents to exist

### Kimiz: "Skills as Primary Abstraction"

**Core Insight**: Skills are the unit of capability; memory supports skill optimization.

```
User Request → Skill Selection → Execution Plan → Tool Orchestration → Result
                    ↓
            Memory learns which skills work best
            (adaptive skill selection)
```

**Principles** (from README):
1. **Skill-centric architecture**: Reusable, composable, learnable
2. **Adaptive learning**: Track model performance, tool success rates
3. **Three-layer memory**: Support skill selection at each layer
4. **Native performance**: Zig for <100ms startup, <50MB memory
5. **Multi-provider routing**: Learn which models work best per task

**Key Difference**: Memory exists to optimize skill selection, not as the primary execution layer.

---

## 3. Memory Management Mechanisms

### Letta: Explicit, Constitution-Driven

**Memory Operations** (explicit API):
```typescript
// Core memory editing
memory_insert(block: "persona", content: string)
memory_replace(block: "human", old: string, new: string)
memory_rethink(block: "persona", new_content: string)

// Retrieval
conversation_search(query: string, limit: int)
archival_memory_search(query: string, limit: int)
archival_memory_insert(content: string, metadata: object)
```

**Context Management Principles**:
1. **System Prompt Learning**: Agents rewrite their own system prompts
2. **Progressive Disclosure**: Load only what's needed, when needed
3. **Compaction**: Summarize old messages, keep references
4. **Subagents**: Delegate memory work to specialized agents
   - Recall: Search past conversations
   - Reflection: Review and update memory
   - Defragmentation: Reorganize memory structure

**Sleep-Time Compute**:
- Primary agent: Handles user interaction (fast model)
- Sleep-time agent: Manages memory asynchronously (stronger model)
- Runs during idle periods to consolidate learning

### Kimiz: Implicit, Learning-Driven

**Memory Operations** (inferred from architecture):
```zig
// Likely API (not yet implemented)
memory.store_interaction(interaction: Interaction)
memory.query_similar(query: string) -> []Memory
memory.update_skill_performance(skill: Skill, success: bool)
memory.get_user_preferences() -> UserProfile
```

**Learning Mechanisms**:
1. **Adaptive Learning**: Track which models work best
2. **Skill Performance**: Monitor success rates per skill
3. **Pattern Recognition**: Detect coding style, preferences
4. **Model Routing**: Learn optimal model selection
5. **Tool Optimization**: Improve tool selection over time

**Implicit Management**:
- No explicit "memory editing" tools
- Learning engine decides what to persist
- Memory updates happen automatically based on outcomes

---

## 4. Storage & Persistence

### Letta: Git-Backed Memory Filesystem (MemFS)

**Architecture**:
```
Agent Memory (in-context)
    ↓
MemFS (local filesystem projection)
    ├── /system/          # In-context memories (always loaded)
    │   ├── persona.md
    │   ├── human.md
    │   └── custom_blocks/
    ├── /skills/          # Agent-owned skills
    ├── /reference/       # External memory files
    └── /projects/        # Project-specific context
    ↓
Git versioning (every change tracked)
    ↓
Remote sync (push/pull for persistence)
```

**Key Features**:
- **Filesystem primitives**: Use bash, scripts, standard tools
- **Git versioning**: Every change has a commit message
- **Concurrent writes**: Multiple subagents via git worktrees
- **Progressive disclosure**: Filetree structure guides navigation
- **Frontmatter metadata**: YAML headers describe file contents

**Example Memory Structure**:
```markdown
---
description: "Core identity and behavioral guidelines"
type: "in-context"
size: "1.2KB"
---

# Persona

I am a memory-first coding agent...
```

### Kimiz: Persistent Store (TBD)

**Likely Architecture** (inferred):
```
Agent Memory (in-memory during session)
    ↓
Persistent Store (SQLite or Postgres)
    ├── interactions table
    ├── skills table
    ├── user_preferences table
    ├── model_performance table
    └── code_patterns table
    ↓
Learning Engine (updates on each interaction)
```

**Characteristics**:
- **Session-scoped state**: Memory persists across restarts
- **Structured data**: Likely relational (not filesystem)
- **Automatic updates**: Learning engine updates on outcomes
- **Query-based retrieval**: SQL queries for memory access
- **No explicit versioning**: Likely append-only logs

---

## 5. Learning Mechanisms

### Letta: Token-Space Continual Learning

**How it works**:
1. **Experience**: Agent interacts with user, gets feedback
2. **Reflection**: Sleep-time agent reviews conversation
3. **Consolidation**: Extract patterns, insights, learnings
4. **Rewrite**: Update system prompt, memory blocks
5. **Verification**: Test new context on similar tasks
6. **Commit**: Version the change with git

**Learning Targets**:
- System prompt (identity, behavioral guidelines)
- Memory blocks (facts, preferences, patterns)
- Skill organization (which skills to load when)
- Context structure (how to organize information)

**Key Insight**: Learning happens in token-space, not in model weights.
- Survives model changes
- Explicit and auditable
- Can be reviewed and reverted
- Accumulates over time

### Kimiz: Adaptive Learning Engine

**How it works**:
1. **Observation**: Track tool success, model performance
2. **Analysis**: Identify patterns in outcomes
3. **Adaptation**: Update skill selection, model routing
4. **Optimization**: Improve future decisions
5. **Persistence**: Store learnings in memory

**Learning Targets**:
- Model performance (which models work best)
- Skill effectiveness (which skills succeed)
- Tool usage (which tools are most useful)
- User preferences (coding style, patterns)
- Code patterns (project-specific conventions)

**Key Insight**: Learning optimizes agent behavior, not context.
- Focuses on decision-making (which skill/model to use)
- Implicit and automatic
- Harder to audit or revert
- Accumulates in memory store

---

## 6. Agent Harness Architecture

### Letta: Memory-First Harness

**Letta Code Architecture**:
```
┌─────────────────────────────────────────────────────────────┐
│ Letta Code (Memory-First Agent Harness)                     │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  MemFS (Git-backed Memory Filesystem)                       │
│  ├── /system/        (in-context memory)                    │
│  ├── /skills/        (agent-owned skills)                   │
│  └── /reference/     (external memory)                      │
│                                                              │
│  Agent Loop                                                  │
│  ├── Context Compiler (assembles context window)            │
│  ├── LLM Inference (with current context)                   │
│  ├── Tool Execution (bash, file ops, etc.)                  │
│  └── Memory Management (update MemFS)                       │
│                                                              │
│  Sleep-Time Compute                                         │
│  ├── Primary Agent (user interaction)                       │
│  └── Sleep-Time Agent (memory consolidation)                │
│                                                              │
│  Subagents                                                   │
│  ├── Recall (search conversations)                          │
│  ├── Reflection (review & update memory)                    │
│  └── Defragmentation (reorganize memory)                    │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

**Key Affordances**:
- Git-backed memory with versioning
- Filesystem operations on memory
- Sleep-time compute for background work
- Subagents for specialized tasks
- Progressive disclosure of context
- Multi-conversation support

### Kimiz: Skill-First Harness

**Kimiz Architecture** (from README):
```
┌─────────────────────────────────────────────────────────────┐
│ Kimiz (Skill-Centric Agent Harness)                         │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Skill System                                               │
│  ├── Code Review                                            │
│  ├── Refactoring                                            │
│  ├── Test Generation                                        │
│  ├── Documentation                                          │
│  └── Debugging                                              │
│                                                              │
│  Agent Loop                                                  │
│  ├── Skill Selection (which skill to use)                   │
│  ├── Execution Plan (how to execute)                        │
│  ├── Tool Orchestration (file, search, bash, web)           │
│  └── Result Aggregation                                     │
│                                                              │
│  Memory System                                              │
│  ├── Short-Term (session context)                           │
│  ├── Working (project-level patterns)                       │
│  └── Long-Term (user preferences)                           │
│                                                              │
│  Learning Engine                                            │
│  ├── Model Performance Tracking                             │
│  ├── Skill Effectiveness Analysis                           │
│  ├── Adaptive Routing                                       │
│  └── Pattern Recognition                                    │
│                                                              │
│  Multi-Provider Support                                     │
│  ├── OpenAI (GPT-4o, o1, o3)                               │
│  ├── Anthropic (Claude 3.5 Sonnet)                         │
│  ├── Google (Gemini 2.0 Flash)                             │
│  ├── Kimi (k1, Moonshot)                                   │
│  └── Fireworks (Open source)                               │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

**Key Affordances**:
- Skill-centric execution model
- Adaptive model routing
- Three-layer memory system
- Learning engine for optimization
- Multi-provider support
- Native Zig performance

---

## 7. What Kimiz Already Covers

✅ **Already Implemented**:
1. **Three-layer memory system** (Short/Working/Long-term)
2. **Skill-centric architecture** (5 built-in skills)
3. **Adaptive learning framework** (model performance tracking)
4. **Multi-provider support** (5 AI providers)
5. **Agent tools** (7 tools: file, search, bash, web)
6. **Session management** (REPL mode, one-shot commands)
7. **Smart model routing** (adaptive selection)
8. **Logging system** (interaction tracking)

---

## 8. Critical Gaps vs Letta

### Gap 1: Memory Persistence & Versioning

**Letta**: Git-backed MemFS with full version history
**Kimiz**: In-memory + TBD persistent store

**Impact**: 
- Letta agents can audit memory changes, revert mistakes
- Kimiz agents lose session memory on restart (currently)
- No explicit versioning of learning

**Recommendation**:
```zig
// Implement git-backed memory filesystem
// Option A: Use libgit2 bindings
// Option B: Shell out to git commands
// Option C: Implement minimal git-compatible format

// Memory structure:
// ~/.kimiz/agents/{agent_id}/
// ├── .git/                    # Git repo
// ├── system/                  # In-context memory
// │   ├── persona.md
// │   ├── preferences.md
// │   └── learned_patterns.md
// ├── skills/                  # Agent-owned skills
// └── reference/               # External memory
```

### Gap 2: Explicit Memory Management Tools

**Letta**: Explicit API for memory operations
**Kimiz**: Implicit learning engine

**Impact**:
- Letta agents can deliberately update their own context
- Kimiz agents rely on automatic learning
- No explicit "rewrite my system prompt" capability

**Recommendation**:
```zig
// Add explicit memory operations
pub const MemoryOps = struct {
    pub fn update_persona(agent: *Agent, new_persona: []const u8) !void
    pub fn add_learned_pattern(agent: *Agent, pattern: Pattern) !void
    pub fn update_preference(agent: *Agent, key: []const u8, value: []const u8) !void
    pub fn search_memory(agent: *Agent, query: []const u8) ![]Memory
};

// Expose to agent as tools
// memory_update_persona(new_persona: string)
// memory_add_pattern(pattern: string)
// memory_search(query: string)
```

### Gap 3: Sleep-Time Compute / Background Learning

**Letta**: Dedicated sleep-time agent for memory consolidation
**Kimiz**: No background processing

**Impact**:
- Letta agents can reflect and improve during idle time
- Kimiz agents only learn during active interactions
- No asynchronous memory consolidation

**Recommendation**:
```zig
// Implement background learning task
pub const BackgroundLearning = struct {
    pub fn consolidate_session(agent: *Agent, session: Session) !void {
        // Extract patterns from session
        // Update learned_patterns.md
        // Reorganize memory structure
        // Commit changes to git
    }
    
    pub fn reflect_on_interactions(agent: *Agent, limit: usize) !void {
        // Review recent interactions
        // Identify mistakes and successes
        // Update system prompt with learnings
    }
};

// Run in background thread or scheduled task
```

### Gap 4: Progressive Disclosure & Context Hierarchy

**Letta**: Explicit filetree structure with frontmatter metadata
**Kimiz**: Flat memory structure (likely)

**Impact**:
- Letta agents navigate memory like a filesystem
- Kimiz agents query memory like a database
- Different mental models for context management

**Recommendation**:
```zig
// Implement hierarchical memory structure
// ~/.kimiz/agents/{agent_id}/
// ├── system/
// │   ├── persona.md          # Always loaded
// │   ├── preferences.md      # Always loaded
// │   └── learned_patterns.md # Always loaded
// ├── reference/
// │   ├── api_docs.md         # Load on demand
// │   ├── code_patterns.md    # Load on demand
// │   └── user_feedback.md    # Load on demand
// └── skills/
//     ├── code_review/
//     ├── refactoring/
//     └── test_generation/

// Metadata in system prompt:
// ## Memory Index
// - /system/persona.md (1.2KB, always loaded)
// - /reference/api_docs.md (5.3KB, load on demand)
// - /skills/code_review/ (skill library)
```

### Gap 5: Subagents for Specialized Tasks

**Letta**: Built-in subagents (Recall, Reflection, Defragmentation)
**Kimiz**: No subagent system

**Impact**:
- Letta agents can delegate memory work
- Kimiz agents handle everything in main loop
- No parallel memory consolidation

**Recommendation**:
```zig
// Implement subagent system
pub const Subagent = struct {
    pub const Type = enum {
        recall,        // Search past interactions
        reflection,    // Review and update memory
        defragmentation, // Reorganize memory
    };
    
    pub fn spawn(agent: *Agent, subagent_type: Type) !Subagent
    pub fn run(subagent: *Subagent, task: Task) !Result
};

// Usage:
// let recall_agent = agent.spawn_subagent(.recall)
// let results = recall_agent.search("similar patterns")
```

### Gap 6: Multi-Conversation Support

**Letta**: Multiple concurrent conversations with shared memory
**Kimiz**: Single conversation per session (likely)

**Impact**:
- Letta agents can maintain parallel interactions
- Kimiz agents handle one conversation at a time
- Different memory sharing models

**Recommendation**:
```zig
// Implement conversation management
pub const Conversation = struct {
    id: []const u8,
    messages: []Message,
    created_at: i64,
    last_message_at: i64,
};

pub const Agent = struct {
    conversations: std.StringHashMap(Conversation),
    
    pub fn create_conversation(agent: *Agent) !Conversation
    pub fn get_conversation(agent: *Agent, id: []const u8) !Conversation
    pub fn search_all_conversations(agent: *Agent, query: []const u8) ![]Message
};
```

### Gap 7: Context Constitution (Explicit Principles)

**Letta**: Written constitution governing context management
**Kimiz**: Implicit principles in learning engine

**Impact**:
- Letta agents have explicit guidelines for self-improvement
- Kimiz agents follow implicit optimization rules
- Different philosophical frameworks

**Recommendation**:
```markdown
# Kimiz Context Constitution

## Principles for Skill-Centric Learning

1. **Skill Mastery**: Continuously improve skill selection and execution
2. **Model Optimization**: Learn which models work best for each task
3. **Pattern Recognition**: Identify and codify coding patterns
4. **User Alignment**: Adapt to user preferences and style
5. **Continuous Improvement**: Learn from every interaction

## Memory Management

- Short-term: Current session context (ephemeral)
- Working: Project-level patterns (session-scoped)
- Long-term: User preferences (persistent)

## Learning Targets

- Skill effectiveness (success rates)
- Model performance (latency, quality, cost)
- Tool usage (which tools are most useful)
- User preferences (style, patterns, constraints)
- Code patterns (project-specific conventions)
```

---

## 9. Integration Roadmap

### Phase 1: Memory Persistence (Sprint 1)
- [ ] Implement git-backed memory filesystem
- [ ] Add memory versioning with commit messages
- [ ] Create memory structure (system/, reference/, skills/)
- [ ] Add frontmatter metadata to memory files

### Phase 2: Explicit Memory Operations (Sprint 2)
- [ ] Add memory_update_persona() tool
- [ ] Add memory_add_pattern() tool
- [ ] Add memory_search() tool
- [ ] Expose to agent as callable tools

### Phase 3: Background Learning (Sprint 2-3)
- [ ] Implement consolidate_session() for pattern extraction
- [ ] Implement reflect_on_interactions() for learning
- [ ] Add background task scheduler
- [ ] Integrate with sleep-time compute concept

### Phase 4: Subagent System (Sprint 3)
- [ ] Implement Recall subagent (search conversations)
- [ ] Implement Reflection subagent (update memory)
- [ ] Implement Defragmentation subagent (reorganize)
- [ ] Add subagent spawning and coordination

### Phase 5: Multi-Conversation Support (Sprint 3-4)
- [ ] Implement conversation management
- [ ] Add conversation switching
- [ ] Implement cross-conversation memory search
- [ ] Add conversation-specific context

### Phase 6: Context Constitution (Sprint 4)
- [ ] Write Kimiz Context Constitution
- [ ] Document learning principles
- [ ] Create memory management guidelines
- [ ] Add constitution to system prompt

---

## 10. Key Takeaways

### What Letta Got Right

1. **Memory as OS**: Treating memory as infrastructure, not a feature
2. **Git-backed versioning**: Full audit trail of learning
3. **Explicit operations**: Agents can deliberately update their context
4. **Progressive disclosure**: Hierarchical memory structure
5. **Sleep-time compute**: Background learning during idle time
6. **Subagents**: Specialized agents for memory work
7. **Constitution**: Explicit principles for self-improvement

### What Kimiz Should Adopt

1. **Git-backed memory filesystem** (highest priority)
2. **Explicit memory operations** (agents can rewrite their own context)
3. **Background learning** (consolidate during idle time)
4. **Hierarchical memory structure** (progressive disclosure)
5. **Subagent system** (delegate memory work)
6. **Multi-conversation support** (parallel interactions)
7. **Context Constitution** (explicit learning principles)

### What Kimiz Does Better

1. **Skill-centric architecture**: More intuitive than memory-first
2. **Adaptive learning**: Automatic optimization vs explicit rewriting
3. **Native performance**: <100ms startup vs Python/Node overhead
4. **Multi-provider support**: Built-in from day one
5. **Simpler mental model**: Skills are easier to understand than memory tiers

### Strategic Positioning

**Letta**: "Memory is the OS"
- Best for: Long-term agents, relationship building, experiential AI
- Strength: Explicit, auditable, model-agnostic learning
- Weakness: Complex, high token overhead, requires active management

**Kimiz**: "Skills are the unit of capability"
- Best for: Coding agents, task-specific optimization, developer tools
- Strength: Simple, fast, adaptive, skill-focused
- Weakness: Implicit learning, harder to audit, less philosophical

**Recommendation**: Kimiz should adopt Letta's memory infrastructure while keeping its skill-centric execution model. This creates a hybrid approach:
- **Execution**: Skill-centric (what Kimiz does well)
- **Learning**: Memory-first (what Letta does well)
- **Result**: Agents that are both practical (skills) and learning-capable (memory)

