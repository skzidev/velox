pub const AngleUnits = union(enum) {
    degree: f64,
    turn: f64,
    radian: f64,

    pub fn fromDegree(degree: f64) AngleUnits {
        return AngleUnits{
            .degree = degree,
        };
    }
};
