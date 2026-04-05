// Example WASM Extension for Kimiz
// Demonstrates host function usage

// External host functions provided by Kimiz
extern "C" {
    fn log(ptr: *const u8, len: usize);
    fn getTimeMs() -> i64;
    fn readFile(path_ptr: *const u8, path_len: usize, out_ptr: *mut u8, out_max: usize) -> i64;
    fn writeFile(path_ptr: *const u8, path_len: usize, content_ptr: *const u8, content_len: usize) -> i64;
}

/// Helper function to log a message
fn log_message(msg: &str) {
    unsafe {
        log(msg.as_ptr(), msg.len());
    }
}

/// Extension initialization
#[no_mangle]
pub extern "C" fn init() -> i32 {
    log_message("Hello Extension initialized!");
    0 // Success
}

/// Add two numbers
#[no_mangle]
pub extern "C" fn add(a: i64, b: i64) -> i64 {
    let result = a + b;
    let msg = format!("Adding {} + {} = {}", a, b, result);
    log_message(&msg);
    result
}

/// Get current time
#[no_mangle]
pub extern "C" fn get_time() -> i64 {
    unsafe { getTimeMs() }
}

/// Read and return file content
#[no_mangle]
pub extern "C" fn read_and_log(path_ptr: *const u8, path_len: usize) -> i64 {
    let mut buffer = [0u8; 1024];
    
    let bytes_read = unsafe {
        readFile(path_ptr, path_len, buffer.as_mut_ptr(), buffer.len())
    };
    
    if bytes_read > 0 {
        let content = String::from_utf8_lossy(&buffer[0..bytes_read as usize]);
        let msg = format!("Read file content: {}", content);
        log_message(&msg);
        bytes_read
    } else {
        log_message("Failed to read file");
        -1
    }
}

/// Extension cleanup
#[no_mangle]
pub extern "C" fn deinit() {
    log_message("Hello Extension shutting down...");
}

// Helper macro for formatting (simplified)
fn format(args: std::fmt::Arguments) -> String {
    std::fmt::format(args)
}
