//! # Power Units
//!
//! Units of motor power
//!

pub const PowerUnit = union(enum) {
    percent: f64,
    volt: f64,
    mvolt: i32,

    pub fn fromPercent(p: f64) PowerUnit {
        return .{
            .percent = p,
        };
    }

    pub fn fromVolt(v: f64) PowerUnit {
        return .{
            .volt = v,
        };
    }

    pub fn fromMillivolt(mv: i32) PowerUnit {
        return .{
            .mvolt = mv,
        };
    }
};
