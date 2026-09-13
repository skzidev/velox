/// Errors that can occur during peripheral device initialization.
pub const DeviceInitError = error{
    /// The port number is invalid. Valid smart ports are 1–20; valid ADI
    /// ports are 1–8.
    InvalidPort,
    /// The port is already being used by another device
    PortUsed,
};

/// Runtime errors for motion commands.
pub const MotionError = error{
    /// The motor has an active target; a conflicting command was rejected.
    MotionInProgress,
    /// A read was attempted while the Inertial sensor is still calibrating.
    StillCalibrating,
};

/// Returns `true` if `port` is a valid VEX V5 smart port number.
pub fn portIsValid(port: u32) bool {
    return (port < 21 and port != 0);
}
