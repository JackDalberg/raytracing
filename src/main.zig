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

    var buf: [4 * 1024]u8 = undefined;
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
        .samples_per_pixel = 400,
        .max_bounce_depth = 50,

        .vertical_fov = 20.0,
        .look_from = .{ 13.0, 2.0, 3.0 },
        .look_at = .{ 0.0, 0.0, 0.0 },
        .view_up = .{ 0.0, 1.0, 0.0 },

        .defocus_angle = 0.6,
        .focus_dist = 10.0,
    };
    const camera = Camera.init(camera_opts);

    // Materials for the world.
    const mat_ground = Material{ .lambertian = .{ .albedo = .{ 0.5, 0.5, 0.5 } } };

    // World full of objects.
    var world = try HitList.init(init.gpa);
    defer world.deinit();
    try world.append(.{
        .sphere = .{ // Ground
            .center = .{ 0.0, -1000.0, 0.0 },
            .radius = 1000.0,
            .material = mat_ground,
        },
    });

    for (0..22) |a| {
        const a_float: f64 = @floatFromInt(@as(i8, @intCast(a)) - 11);
        for (0..22) |b| {
            const b_float: f64 = @floatFromInt(@as(i8, @intCast(b)) - 11);
            // rand_double below
            const choose_mat = rand.float(f64);
            const center = Point{ a_float + 0.9 * rand.float(f64), 0.2, b_float + 0.9 * rand.float(f64) };

            if (vec.len(center - Point{ 4.0, 0.2, 0.0 }) > 0.9) {
                var sphere_material: Material = undefined;
                if (choose_mat < 0.8) {
                    // diffuse
                    const albedo = vec.randomVec(rand) * vec.randomVec(rand);
                    sphere_material = .{ .lambertian = .{ .albedo = albedo } };
                } else if (choose_mat < 0.95) {
                    // metal
                    const albedo = Vec3{ 0.5, 0.5, 0.5 } + vec.scale(Vec3{ 1.0, 1.0, 1.0 } + vec.randomVec(rand), 0.25);
                    const fuzz = rand.float(f64) * 0.5;
                    sphere_material = .{ .metal = .{ .albedo = albedo, .fuzz = fuzz } };
                } else {
                    // glass
                    sphere_material = .{ .dielectric = .{ .refraction_index = 1.5 } };
                }
                try world.append(.{
                    .sphere = .{
                        .center = center,
                        .radius = 0.2,
                        .material = sphere_material,
                    },
                });
            }
        }
    }

    const material1 = Material{ .dielectric = .{ .refraction_index = 1.5}};
    try world.append(.{
        .sphere = .{
            .center = .{ 0.0, 1.0, 0.0 },
            .radius = 1.0,
            .material = material1,
        },
    });
    const material2 = Material{ .lambertian = .{ .albedo = .{ 0.4, 0.2, 0.1 }} };
    try world.append(.{
        .sphere = .{
            .center = .{ -4.0, 1.0, 0.0 },
            .radius = 1.0,
            .material = material2,
        },
    });
    const material3 = Material{ .metal = .{ .albedo = .{ 0.7, 0.6, 0.5}, .fuzz = 0.0 }};
    try world.append(.{
        .sphere = .{
            .center = .{ 4.0, 1.0, 0.0 },
            .radius = 1.0,
            .material = material3,
        },
    });

    try camera.render(.{ .hit_list = world });
}

