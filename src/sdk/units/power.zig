//! # Power Units
//!
//! Units of motor power
//!

pub const PowerUnit = union(enum) {
    percent: f64,
    volts: f64,
    mvolts: i32,

    pub fn fromPercent(p: f64) PowerUnit {
        return .{
            .percent = p,
            .volt = (p / 100) * 127,
            .mvolt = (p / 100) * 127000,
        };
    }

    pub fn fromVolt(v: f64) PowerUnit {
        return .{
            .volt = v,
            .mvolt = v * 1000,
            .percent = v / 127,
        };
    }

    pub fn fromMillivolt(mv: i32) PowerUnit {
        return .{
            .mvolt = mv,
            .volt = mv / 1000,
            .percent = mv / 127000,
        };
    }
};
