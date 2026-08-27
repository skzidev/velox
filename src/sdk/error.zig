/// Errors that can occur during peripheral device initialization.
pub const DeviceInitError = error{
    /// The port number is invalid. Valid smart ports are 1–20; valid ADI
    /// ports are 1–8.
    InvalidPortError,
};

/// Returns `true` if `port` is a valid VEX V5 smart port number.
pub fn portIsValid(port: u32) bool {
    return (port < 21 and port != 0);
}
