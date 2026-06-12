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
rand: std.Random,

aspect_ratio: f64,
image_width: u16,
image_height: u16,
center: Point,
pixel00: Point,
pixel_delta_u: Vec3,
pixel_delta_v: Vec3,
samples_per_pixel: u16,
pixel_samples_scale: f64,
max_bounce_depth: u16,

const Camera = @This();

// All values in the Camera are being derived from the fields of the Options struct.
pub const Options = struct {
    w: *std.Io.Writer,
    log: *std.Io.Writer,
    rand: std.Random,

    aspect_ratio: f64 = 1.0,
    image_width: u16 = 100,
    center: Point = .{ 0.0, 0.0, 0.0 },
    samples_per_pixel: u16 = 10,
    max_bounce_depth: u16 = 10,
};

pub fn init(opts: Options) Camera {
    const w = opts.w;
    const log = opts.log;
    const rand = opts.rand;

    const aspect_ratio = opts.aspect_ratio;
    const image_width = opts.image_width;
    const image_height: u16 = @max(1, @as(u16, @intFromFloat(@as(f64, @floatFromInt(image_width)) / aspect_ratio)));
    const center = opts.center;
    const max_bounce_depth = opts.max_bounce_depth;

    const pixel_samples_scale: f64 = 1.0 / @as(f64, @floatFromInt(opts.samples_per_pixel));
    const samples_per_pixel = opts.samples_per_pixel;

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
        .rand = rand,

        .aspect_ratio = aspect_ratio,
        .image_width = image_width,
        .image_height = image_height,
        .center = center,
        .pixel00 = pixel00,
        .pixel_delta_u = pixel_delta_u,
        .pixel_delta_v = pixel_delta_v,
        .pixel_samples_scale = pixel_samples_scale,
        .samples_per_pixel = samples_per_pixel,
        .max_bounce_depth = max_bounce_depth,
    };
}

pub fn render(self: Camera, world: Hittable) !void {
    try self.w.print("P3\n{} {}\n255\n", .{ self.image_width, self.image_height });

    for (0..self.image_height) |j| {
        try self.log.print("\rScanlines remaining: {} ", .{self.image_height - j});
        for (0..self.image_width) |i| {
            var pixel_color = Color{ 0.0, 0.0, 0.0 };
            for (0..self.samples_per_pixel) |_| {
                const ray = self.getRay(i, j);
                pixel_color = pixel_color + self.rayColor(ray, world, 0);
            }

            try vec.writeColor(self.w, vec.scale(pixel_color, self.pixel_samples_scale));
        }
    }
    try self.w.flush();
    try self.log.writeAll("\rDone.                         \n");
}

fn sampleSquare(self: Camera) Vec3 {
    return .{
        self.rand.float(f64) - 0.5,
        self.rand.float(f64) - 0.5,
        0.0,
    };
}

fn getRay(self: Camera, i: usize, j: usize) Ray {
    const offset = self.sampleSquare();
    const pixel_sample = self.pixel00 + vec.scale(self.pixel_delta_u, offset[0] + @as(f64, @floatFromInt(i))) + vec.scale(self.pixel_delta_v, offset[1] + @as(f64, @floatFromInt(j)));

    const ray_direction = pixel_sample - self.center;
    return .{ .origin = self.center, .direction = ray_direction };
}

fn rayColor(self: Camera, ray: Ray, world: Hittable, depth: u16) Color {
    if (depth >= self.max_bounce_depth) {
        return .{ 0.0, 0.0, 0.0 };
    }

    const hr = world.hit(ray, 0.001, std.math.inf(f64));
    if (hr.is_hit) {
        //return vec.scale(hr.normal + Color{ 1.0, 1.0, 1.0 }, 0.5);
        const direction = hr.normal + vec.randomUnitVec(self.rand);
        return vec.scale(self.rayColor(Ray{ .origin = hr.point, .direction = direction }, world, depth + 1), 0.5);
    }
    // TODO: Make this work in a non bad way.
    //const unit_direction = vec.unit(r.direction);
    const unit_direction = ray.direction / @as(Vec3, @splat(@sqrt(@reduce(.Add, ray.direction * ray.direction))));
    const a = 0.5 * (unit_direction[1] + 1.0);
    return Color{ 1.0, 1.0, 1.0 } * vec.vec3(1.0 - a) + Color{ 0.5, 0.7, 1.0 } * vec.vec3(a);
}
