const vec = @import("vec.zig");
const Point = vec.Point;
const Vec3 = vec.Vec3;

const Ray = @This();

origin: Point,
direction: Vec3 = .{ 0.0, 0.0, 0.0 },
time: f32 = 0.0,

pub fn atTime(ray: Ray, t: f32) Point {
    return ray.origin + ray.direction * vec.splat(t);
}
