const vec = @import("vec.zig");

pub const Ray = struct {
    origin: vec.Point,
    direction: vec.Vec3,

    pub fn init(origin: vec.Point, direction: vec.Vec3) Ray {
        return .{
            .origin = origin,
            .direction = direction,
        };
    }

    pub fn atTime(ray: Ray, t: f64) vec.Point {
        return ray.origin + ray.direction * vec.vec3(t);
    }
};
