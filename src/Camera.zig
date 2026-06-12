const std = @import("std");

const hittable = @import("hittable.zig");
const Hittable = hittable.Hittable;
const HitRecord = hittable.HitRecord;

const Ray = @import("Ray.zig");

const vec = @import("vec.zig");
const Vec3 = vec.Vec3;
const Point = vec.Point;
const Color = vec.Color;

w: *std.Io.Writer,
log: *std.Io.Writer,
aspect_ratio: f64,
image_width: u16,
image_height: u16,
center: Point,
pixel00: Point,
pixel_delta_u: Vec3,
pixel_delta_v: Vec3,

const Camera = @This();

// All values in the Camera are being derived from the fields of the Options struct.
pub const Options = struct {
    w: *std.Io.Writer,
    log: *std.Io.Writer,
    aspect_ratio: f64 = 1.0,
    image_width: u16 = 100,
};

pub fn init(opts: Options) Camera {
    const aspect_ratio = opts.aspect_ratio;
    const image_width = opts.image_width;
    const w = opts.w;
    const log = opts.log;

    const image_height: u16 = @max(1, @as(u16, @intFromFloat(@as(f64, @floatFromInt(image_width)) / aspect_ratio)));
    const center = Vec3{ 0.0, 0.0, 0.0};
    
    // Viewport dimensions
    const focal_length = 1.0;
    const viewport_height = 2.0;
    const viewport_width = viewport_height * (@as(f64, @floatFromInt(image_width)) / image_height);

    const viewport_u = Vec3{ viewport_width, 0.0, 0.0 };
    const viewport_v = Vec3{ 0.0, -viewport_height, 0.0 };

    const pixel_delta_u = viewport_u / vec.splat(Vec3, image_width);
    const pixel_delta_v = viewport_v / vec.splat(Vec3, image_height);

    // Calculate postion of top left.
    const viewport_upper_left = center - Vec3{ 0.0, 0.0, focal_length } - vec.scale(viewport_u + viewport_v, 0.5);
    const pixel00 = viewport_upper_left + vec.scale(pixel_delta_u + pixel_delta_v, 0.5);

    return .{
        .w = w,
        .log = log,
        .aspect_ratio = aspect_ratio,
        .image_width = image_width,
        .image_height = image_height,
        .center = center,
        .pixel00 = pixel00,
        .pixel_delta_u = pixel_delta_u,
        .pixel_delta_v = pixel_delta_v,
    };
}

pub fn render(self: Camera, world: Hittable) !void {
    try self.w.print("P3\n{} {}\n255\n", .{ self.image_width, self.image_height });

    for (0..self.image_height) |j| {
        try self.log.print("\rScanlines remaining: {} ", .{self.image_height - j});
        for (0..self.image_width) |i| {
            const pixel_center = self.pixel00 + vec.scale(self.pixel_delta_u, @as(f64, @floatFromInt(i))) + vec.scale(self.pixel_delta_v, @as(f64, @floatFromInt(j)));
            const ray_dir = pixel_center - self.center;
            const ray = Ray.init(self.center, ray_dir);

            const pixel_color = rayColor(ray, world);
            try vec.writeColor(self.w, pixel_color);
        }
    }
    try self.w.flush();
    try self.log.writeAll("\rDone.                         \n");
}

fn rayColor(ray: Ray, world: Hittable) Color {
    const hr = world.hit(ray, 0, std.math.inf(f64));
    if (hr.is_hit) {
        return vec.scale(hr.normal + Color{ 1.0, 1.0, 1.0 }, 0.5);
    }
    // TODO: Make this work in a non bad way.
    //const unit_direction = vec.unit(r.direction);
    const unit_direction = ray.direction / @as(Vec3, @splat(@sqrt(@reduce(.Add, ray.direction * ray.direction))));
    const a = 0.5 * (unit_direction[1] + 1.0);
    return Color{ 1.0, 1.0, 1.0 } * vec.vec3(1.0 - a) + Color{ 0.5, 0.7, 1.0 } * vec.vec3(a);
}
