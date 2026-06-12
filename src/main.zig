const std = @import("std");

const vec = @import("vec.zig");
const Vec3 = vec.Vec3;
const Point = vec.Point;
const Color = vec.Color;

const Ray = @import("Ray.zig");

const hittable = @import("hittable.zig");
const Hittable = hittable.Hittable;
const Sphere = hittable.Sphere;
const HitRecord = hittable.HitRecord;

const HitList = @import("HitList.zig");

const Camera = @import("Camera.zig");

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    var buf: [1024]u8 = undefined;
    var file_writer = std.Io.File.stdout().writer(io, &buf);
    var log_writer = std.Io.File.stderr().writer(io, &.{});
    const w = &file_writer.interface;
    const log = &log_writer.interface;

    const camera_opts = Camera.Options{
        .w = w,
        .log = log,
        .aspect_ratio = 16.0 / 9.0,
        .image_width = 400,
    };
    const camera = Camera.init(camera_opts);

    // World full of objects.
    var world = try HitList.init(init.gpa);
    defer world.deinit();
    try world.append(.{ .sphere = .{
        .center = .{ 0.0, 0.0, -1.0 },
        .radius = 0.5,
    } });
    try world.append(.{ .sphere = .{
        .center = .{ 0.0, -100.5, -1.0 },
        .radius = 100.0,
    } });

    try camera.render(.{ .hit_list = world });
}

fn rayColor(r: Ray, world: Hittable) Color {
    const hr = world.hit(r, 0, std.math.inf(f64));
    if (hr.is_hit) {
        return vec.scale(hr.normal + Color{ 1.0, 1.0, 1.0 }, 0.5);
    }
    // TODO: Make this work in a non bad way.
    //const unit_direction = vec.unit(r.direction);
    const unit_direction = r.direction / @as(Vec3, @splat(@sqrt(@reduce(.Add, r.direction * r.direction))));
    const a = 0.5 * (unit_direction[1] + 1.0);
    return Color{ 1.0, 1.0, 1.0 } * vec.vec3(1.0 - a) + Color{ 0.5, 0.7, 1.0 } * vec.vec3(a);
}
