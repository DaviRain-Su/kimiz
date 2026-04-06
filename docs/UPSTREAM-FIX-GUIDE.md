# Upstream Fix Guide: uucode + libvaxis Zig 0.16 Compatibility

> **Goal**: Fix `DaviRain-Su/uucode` and `DaviRain-Su/libvaxis` so KimiZ can depend on remote `libvaxis` instead of local vendored copies.

## Current Status

- `DaviRain-Su/uucode` fork has partial Zig 0.16 fixes (`Io.Clock.now` API) but is missing:
  1. `try std.Io.Clock.awake.now(io)` → `std.Io.Clock.awake.now(io)` (10 occurrences)
  2. `for (self.fields)` → `inline for (self.fields)` in `config.zig` (3 occurrences)
  3. `inline for (resolved_tables, 0..)` → `while` loop in `tables.zig` (2 occurrences)
- `DaviRain-Su/libvaxis` points to the old `uucode` commit (`1712f78e`), which still fails on Zig 0.16.

## Step 1: Fix uucode

```bash
git clone https://github.com/DaviRain-Su/uucode.git
cd uucode

# Apply the prepared patch
git apply patches/uucode-zig016.patch
# Or if you copied the patch elsewhere:
# git apply /path/to/patches/uucode-zig016.patch

# Verify
git diff --stat
# Expected: src/build/Ucd.zig, src/build/tables.zig, src/config.zig

# Commit and push
git add -A
git commit -m "fix: complete Zig 0.16 compatibility

- std.Io.Clock.awake.now() no longer returns error union
- inline for over comptime-only structs in config.zig
- while loops instead of inline for over resolved_tables to avoid
  storing runtime values in compile-time variables"
git push origin main

# Get the new commit hash
NEW_COMMIT=$(git rev-parse HEAD)
echo "New uucode commit: $NEW_COMMIT"
```

## Step 2: Get new uucode package hash

```bash
# In any directory with zig 0.16:
NEW_HASH=$(zig fetch "git+https://github.com/DaviRain-Su/uucode#${NEW_COMMIT}")
echo "New uucode hash: $NEW_HASH"
```

Example output:
```
uucode-0.2.0-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

## Step 3: Update libvaxis

```bash
cd ..
git clone https://github.com/DaviRain-Su/libvaxis.git
cd libvaxis

# Edit build.zig.zon
```

Change:
```zig
.uucode = .{
    .url = "git+https://github.com/DaviRain-Su/uucode#OLD_COMMIT",
    .hash = "uucode-0.2.0-OLD_HASH",
},
```

To:
```zig
.uucode = .{
    .url = "git+https://github.com/DaviRain-Su/uucode#<NEW_COMMIT>",
    .hash = "<NEW_HASH>",
},
```

Then:
```bash
# Optional: verify libvaxis still compiles with the new uucode
zig build

git add build.zig.zon
git commit -m "deps: update uucode to Zig 0.16 compatible version"
git push origin main
```

## Step 4: Verify remote vaxis in KimiZ

Once both upstream repos are updated, in the KimiZ repo:

```bash
git checkout feature/tui-implementation

# 1. Remove local zig-pkg cache patch (optional, zig will refetch)
rm -rf zig-pkg/uucode-*

# 2. Uncomment vaxis in build.zig.zon
# Edit build.zig.zon to add:
# .vaxis = .{
#     .url = "git+https://github.com/DaviRain-Su/libvaxis",
#     .hash = "...",
# },

# 3. Uncomment vaxis_dep in build.zig and mod imports

# 4. Test
zig build
```

## Patch File Location

- `patches/uucode-zig016.patch` — ready to apply in `DaviRain-Su/uucode`

## Notes

- The `zig-pkg/` directory is already `.gitignore`d in KimiZ. Until upstream is fixed, KimiZ uses a locally patched `zig-pkg/uucode-*` for development.
- Do **not** commit `vendor/uucode/` or large vendored dependencies to the KimiZ repo.
