//! kimiz-workspace - Workspace context and file management
//! Provides workspace-aware operations for the agent

const std = @import("std");

pub const context = @import("context.zig");
pub const WorkspaceInfo = context.WorkspaceInfo;

/// Initialize workspace module
pub fn init() void {
    // Module initialization if needed
}

/// Deinitialize workspace module
pub fn deinit() void {
    // Module cleanup if needed
}
