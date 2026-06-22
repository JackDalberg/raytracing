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

const bvh = @import("bvh.zig");
const BvhNode = bvh.BvhNode;
const BvhTree = bvh.BvhTree;

const texture = @import("texture.zig");
const Texture = texture.Texture;
const Checker = texture.Checker;

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
        .image_width = 100,
        .samples_per_pixel = 100,
        .max_bounce_depth = 50,

        .vertical_fov = 20.0,
        .look_from = .{ 13.0, 2.0, 3.0 },
        .look_at = .{ 0.0, 0.0, 0.0 },
        .view_up = .{ 0.0, 1.0, 0.0 },

        .defocus_angle = 0.0,
        .focus_dist = 10.0,
    };
    var camera = Camera.init(camera_opts);

    //    const args = try init.minimal.args.toSlice(init.gpa);
    //    defer init.gpa.free(args);
    //    var scene: []const u8 = "";
    //    if (args.len >= 2) {
    //        scene = args[1];
    //    }
    //
    //    if (std.mem.eql(u8, scene, "checker")) {
    try checkeredSpheres(init.gpa, rand, &camera);
    //   } else {
    //        try manySpheres(init.gpa, rand, &camera);
    //    }
}

pub fn checkeredSpheres(gpa: std.mem.Allocator, rand: std.Random, camera: *Camera) !void {
    // Materials for the world.
    var even = Texture{ .solid_color = .{ .color = .{ 0.2, 0.3, 0.1 } } };
    var odd = Texture{ .solid_color = .{ .color = .{ 0.9, 0.9, 0.9 } } };
    var checker = Texture{ .checker = .{ .even = &even, .odd = &odd, .inverse_scale = 1.0 / 0.32 } };
    const mat_checker = Material{ .lambertian = .{ .texture = &checker } };

    var world = try HitList.init(gpa);
    defer world.deinit();
    try world.append(.{
        .sphere = .init(
            .{ .origin = .{ 0.0, -10.0, 0.0 } },
            10.0,
            mat_checker,
        ),
    });
    try world.append(.{
        .sphere = .init(
            .{ .origin = .{ 0.0, 10.0, 0.0 } },
            10.0,
            mat_checker,
        ),
    });

    var tree = BvhTree.init(gpa, rand);
    defer tree.deinit();
    const root = try tree.fromSlice(world.list.items);

    try camera.render(root.*);
}

pub fn manySpheres(gpa: std.mem.Allocator, rand: std.Random, camera: *Camera) !void {
    // Materials for the world.
    var even = Texture{ .solid_color = .{ .color = .{ 0.2, 0.3, 0.1 } } };
    var odd = Texture{ .solid_color = .{ .color = .{ 0.9, 0.9, 0.9 } } };
    var checker = Texture{ .checker = .{ .even = &even, .odd = &odd, .inverse_scale = 1.0 / 0.32 } };
    const mat_ground = Material{ .lambertian = .{ .texture = &checker } };

    // World full of objects.
    var world = try HitList.init(gpa);
    defer world.deinit();
    try world.append(.{
        .sphere = .init( // Ground
            .{ .origin = .{ 0.0, -1000.0, 0.0 } },
            1000.0,
            mat_ground,
        ),
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
                    sphere_material = .{ .lambertian = try .fromColor(gpa, albedo) };
                    defer gpa.destroy(sphere_material.lambertian.texture);
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
                    .sphere = .init(
                        //.{ .origin = center, .direction = vec.splat(rand.float(f64) * 0.2) },
                        .{ .origin = center },
                        0.2,
                        sphere_material,
                    ),
                });
            }
        }
    }

    const material1 = Material{ .dielectric = .{ .refraction_index = 1.5 } };
    try world.append(.{
        .sphere = .init(
            .{ .origin = .{ 0.0, 1.0, 0.0 } },
            1.0,
            material1,
        ),
    });
    const material2 = Material{ .lambertian = try .fromColor(gpa, .{ 0.4, 0.2, 0.1 }) };
    defer gpa.destroy(material2.lambertian.texture);
    try world.append(.{
        .sphere = .init(
            .{ .origin = .{ -4.0, 1.0, 0.0 } },
            1.0,
            material2,
        ),
    });
    const material3 = Material{ .metal = .{ .albedo = .{ 0.7, 0.6, 0.5 }, .fuzz = 0.0 } };
    try world.append(.{
        .sphere = .init(
            .{ .origin = .{ 4.0, 1.0, 0.0 } },
            1.0,
            material3,
        ),
    });

    var tree = BvhTree.init(gpa, rand);
    defer tree.deinit();
    const root = try tree.fromSlice(world.list.items);

    try camera.render(root.*);
}
