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

const mat = @import("material.zig");
const Material = mat.Material;

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    var buf: [1024]u8 = undefined;
    var file_writer = std.Io.File.stdout().writer(io, &buf);
    var log_writer = std.Io.File.stderr().writer(io, &.{});
    var prng = std.Random.DefaultPrng.init(42);
    const w = &file_writer.interface;
    const log = &log_writer.interface;
    const rand = prng.random();

    const camera_opts = Camera.Options{
        .w = w,
        .log = log,
        .rand = rand,
        .aspect_ratio = 16.0 / 9.0,
        .image_width = 400,
        .samples_per_pixel = 100,
        .max_bounce_depth = 50,
    };
    const camera = Camera.init(camera_opts);

    // Materials for the world.
    const mat_ground = Material{ .lambertian = .{ .albedo = .{ 0.8, 0.8, 0.0 } } };
    const mat_center = Material{ .lambertian = .{ .albedo = .{ 0.1, 0.2, 0.5 } } };
    const mat_left = Material{ .metal = .init(.{ 0.8, 0.8, 0.8 }, 0.3) };
    const mat_right = Material{ .metal = .init(.{ 0.8, 0.6, 0.2 }, 1.0) };

    // World full of objects.
    var world = try HitList.init(init.gpa);
    defer world.deinit();
    try world.append(.{
        .sphere = .{ // Center
            .center = .{ 0.0, 0.0, -1.2 },
            .radius = 0.5,
            .material = mat_center,
        },
    });
    try world.append(.{
        .sphere = .{ // Ground
            .center = .{ 0.0, -100.5, -1.0 },
            .radius = 100.0,
            .material = mat_ground,
        },
    });
    try world.append(.{
        .sphere = .{ // Left
            .center = .{ -1.0, 0.0, -1.0 },
            .radius = 0.5,
            .material = mat_left,
        },
    });
    try world.append(.{
        .sphere = .{ // Right
            .center = .{ 1.0, 0.0, -1.0 },
            .radius = 0.5,
            .material = mat_right,
        },
    });

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
