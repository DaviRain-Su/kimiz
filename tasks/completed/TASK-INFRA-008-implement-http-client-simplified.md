### TASK-INFRA-008: u5b9eu73b0 HTTP Client

**u72b6u6001**: u2705 u5df2u5b8cu6210uff08u5df2u5347u7ea7u4e3au5b8cu6574u5b9eu73b0uff09
**u5b8cu6210u65e5u671f**: 2026-04-05
**u5b9eu9645u8017u65f6**: 3u5c0fu65f6

**u8bf4u660e**:
u521du59cbu7248u672cu56e0 Zig 0.16 u7684 `std.Io.IoUring` u65e0u6cd5u4f7fu7528u800cu91c7u7528u5360u4f4du5b9eu73b0u3002
u540eu6765u53d1u73b0u6b63u786eu65b9u6cd5u662fu901au8fc7 `std.process.Init.io` u83b7u53d6 `std.Io`uff0c
u73b0u5df2u5b8cu5168u91cdu5199u4e3au4f7fu7528 Zig 0.16 u7684 `std.http.Client` u5b9eu9645 APIu3002

**u5b9eu73b0u5185u5bb9**:
1. u2705 `HttpClient.initWithIo(allocator, io)` - u63a5u53d7 `std.Io` u53c2u6570
2. u2705 `HttpClient.init(allocator)` - u4eceu5168u5c40 IoManager u83b7u53d6 Io
3. u2705 `postJson()` - u4f7fu7528 `request`/`sendBodyComplete`/`receiveHead`/`allocRemaining`
4. u2705 `postStream()` - SSE u6d41u5f0fu8bfbu53d6uff0cu4f7fu7528 `readVec` u9010u5757u8bfbu53d6
5. u2705 `IoManager` - u5b58u50a8 `std.Io` u5b9eu4f8buff0cu4ece `main` u521du59cbu5316

**u67b6u6784**:
```
main.zig
  u2514u2500 init.io u2500u2500u2192 IoManager (u5168u5c40u5355u4f8b)
                      u2514u2500u2192 HttpClient.init() u2500u2500u2192 std.http.Client
```

**u5df2u77e5u9650u5236**:
- HTTP u91cdu8bd5u65e0u5ef6u8fdfuff08`std.time.sleep` u5728 Zig 0.16 u9700u8981 `std.Io`uff09
- u672au5b9eu73b0u8fdeu63a5u6c60u548c Keep-Alive u4f18u5316

**u76f8u5173u6587u4ef6**:
- `src/http.zig` - HTTP Client u5b9eu73b0
- `src/utils/io_manager.zig` - IoManager
- `src/main.zig` - IoManager u521du59cbu5316

**u7f16u8bd1u72b6u6001**:
```bash
$ zig build      # u2705 u6210u529f
$ zig build test # u2705 u6210u529f
```
