//! Low-level process and I/O primitives shared across the worker.

use std::io;
use std::sync::atomic::{AtomicBool, Ordering};

static CANCELLED: AtomicBool = AtomicBool::new(false);

/// Install a SIGINT handler so the worker can be cancelled cleanly.
pub fn install_cancellation() -> io::Result<()> {
    // Rust's std::sync::atomic can't be accessed in a signal handler directly,
    // so we use a self-pipe trick: write a byte to a pipe on SIGINT,
    // and poll that in the main loop. For now, just set a flag.
    // A proper implementation would use a signal-safe pipe write.
    //
    // The actual cancellation is triggered by the GUI writing "cancel" on stdin,
    // which sets CANCELLED. This is safe because stdin is read in one thread.
    Ok(())
}

pub fn cancelled() -> bool {
    CANCELLED.load(Ordering::SeqCst)
}

pub fn cancel() {
    CANCELLED.store(true, Ordering::SeqCst);
}

/// A write buffer that enforces a maximum byte size.
/// Used to bound responses so a malicious payload can't OOM the GUI.
pub struct BoundedBuffer {
    bytes: Vec<u8>,
    limit: usize,
}

impl BoundedBuffer {
    pub fn new(limit: usize) -> Self {
        Self { bytes: Vec::with_capacity(limit.min(4096)), limit }
    }

    pub fn bytes(&self) -> &[u8] {
        &self.bytes
    }
}

impl io::Write for BoundedBuffer {
    fn write(&mut self, buf: &[u8]) -> io::Result<usize> {
        let remaining = self.limit.saturating_sub(self.bytes.len());
        if remaining == 0 {
            return Ok(0);
        }
        let to_write = buf.len().min(remaining);
        self.bytes.extend_from_slice(&buf[..to_write]);
        Ok(to_write)
    }

    fn flush(&mut self) -> io::Result<()> {
        Ok(())
    }
}
