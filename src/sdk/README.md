# Velox SDK

This is the Velox SDK. It contains:

- Device interfaces
- Controller interface
- Unit definitions

It's designed to use Named Parameters with Explicit units, which should _mostly_ mitigate unit errors. This means that the caller of a function specifies what units the function should return. For instance, motor temperature:

```zig
const tempF = motor.temp(.fahrenheit);
```
