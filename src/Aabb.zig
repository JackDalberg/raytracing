const vec = @import("vec.zig");
const Point = vec.Point;

const Ray = @import("Ray.zig");

const hittable = @import("hittable.zig");
const HitRecord = hittable.HitRecord;

const Aabb = @This();

x0: f32,
x1: f32,
y0: f32,
y1: f32,
z0: f32,
z1: f32,

pub fn init(a: Point, b: Point) Aabb {
    return .{
        .x0 = @min(a[0], b[0]),
        .x1 = @max(a[0], b[0]),
        .y0 = @min(a[1], b[1]),
        .y1 = @max(a[1], b[1]),
        .z0 = @min(a[2], b[2]),
        .z1 = @max(a[2], b[2]),
    };
}

// Check whether the ray_in intersects ALL intervals in the given time range.
pub fn intersect(self: Aabb, ray_in: Ray, t_min: f32, t_max: f32) bool {
    const origin = ray_in.origin;
    const direction = ray_in.direction;

    var t0 = (self.x0 - origin[0]) / direction[0];
    var t1 = (self.x1 - origin[0]) / direction[0];

    var max_possible_time = @min(t_max, @max(t0, t1));
    var min_possible_time = @max(t_min, @min(t0, t1));

    if (max_possible_time <= min_possible_time) {
        return false;
    }

    t0 = (self.y0 - origin[1]) / direction[1];
    t1 = (self.y1 - origin[1]) / direction[1];

    max_possible_time = @min(t_max, @max(t0, t1));
    min_possible_time = @max(t_min, @min(t0, t1));

    if (max_possible_time <= min_possible_time) {
        return false;
    }

    t0 = (self.z0 - origin[2]) / direction[2];
    t1 = (self.z1 - origin[2]) / direction[2];

    max_possible_time = @min(t_max, @max(t0, t1));
    min_possible_time = @max(t_min, @min(t0, t1));

    if (max_possible_time <= min_possible_time) {
        return false;
    }
    return true;
}

pub fn combine(box1: Aabb, box2: Aabb) Aabb {
    return .{
        .x0 = @min(box1.x0, box2.x0),
        .x1 = @max(box1.x1, box2.x1),
        .y0 = @min(box1.y0, box2.y0),
        .y1 = @max(box1.y1, box2.y1),
        .z0 = @min(box1.z0, box2.z0),
        .z1 = @max(box1.z1, box2.z1),
    };
}
