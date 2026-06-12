const vec = @import("vec.zig");
const Point = vec.Point;
const Vec3 = vec.Vec3;

const Ray = @This();

origin: Point,
direction: Vec3,

pub fn init(origin: Point, direction: Vec3) Ray {
    return .{
        .origin = origin,
        .direction = direction,
    };
}

pub fn atTime(ray: Ray, t: f64) Point {
    return ray.origin + ray.direction * vec.vec3(t);
}
