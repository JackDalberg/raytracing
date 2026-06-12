const std = @import("std");

const vec = @import("vec.zig");
const Vec3 = vec.Vec3;
const Point = vec.Point;
const Color = vec.Color;

const ray = @import("ray.zig");
const Ray = ray.Ray;

const hittable = @import("hittable.zig");
const Hittable = hittable.Hittable;
const Sphere = hittable.Sphere;
const HitRecord = hittable.HitRecord;

const HitList = @import("HitList.zig");

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    var buf: [1024]u8 = undefined;
    var file_writer = std.Io.File.stdout().writer(io, &buf);
    var log_writer = std.Io.File.stderr().writer(io, &.{});
    const w = &file_writer.interface;
    const log = &log_writer.interface;

    // Image size
    const aspect_ratio = 16.0 / 9.0;
    const image_width: usize = 400;
    const image_height = @max(@as(comptime_int, @intFromFloat(@as(comptime_float, @floatFromInt(image_width)) / aspect_ratio)), 1);

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

    // Camera
    const focal_length = 1.0;
    const viewport_height = 2.0;
    const viewport_width = viewport_height * (@as(f64, @floatFromInt(image_width)) / image_height);
    const camera_center = Point{ 0.0, 0.0, 0.0 };

    const viewport_u = Vec3{ viewport_width, 0.0, 0.0 };
    const viewport_v = Vec3{ 0.0, -viewport_height, 0.0 };

    const pixel_delta_u = viewport_u / vec.splat(Vec3, image_width);
    const pixel_delta_v = viewport_v / vec.splat(Vec3, image_height);

    // Calculate postion of top left.
    const viewport_upper_left = camera_center - Vec3{ 0.0, 0.0, focal_length } - vec.scale(viewport_u, 0.5) - vec.scale(viewport_v, 0.5);
    const pixel00_loc = viewport_upper_left + vec.scale(pixel_delta_u, 0.5) + vec.scale(pixel_delta_v, 0.5);

    try w.print("P3\n{} {}\n255\n", .{ image_width, image_height });

    for (0..image_height) |j| {
        try log.print("\rScanlines remaining: {} ", .{image_height - j});
        for (0..image_width) |i| {
            const pixel_center = pixel00_loc + vec.scale(pixel_delta_u, @as(f64, @floatFromInt(i))) + vec.scale(pixel_delta_v, @as(f64, @floatFromInt(j)));
            const ray_dir = pixel_center - camera_center;
            const r = Ray.init(camera_center, ray_dir);

            const pixel_color = rayColor(r, .{ .hit_list = world });
            try vec.writeColor(w, pixel_color);
        }
    }
    try w.flush();
    try log.writeAll("\rDone.                         \n");
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
