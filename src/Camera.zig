const std = @import("std");

const hittable = @import("hittable.zig");
const Hittable = hittable.Hittable;
const HitRecord = hittable.HitRecord;

const Ray = @import("Ray.zig");

const vec = @import("vec.zig");
const Vec3 = vec.Vec3;
const Point = vec.Point;
const Color = vec.Color;

const mat = @import("material.zig");
const Material = mat.Material;

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
defocus_angle: f64,
defocus_disk_u: Vec3,
defocus_disk_v: Vec3,

const Camera = @This();

// All values in the Camera are being derived from the fields of the Options struct.
pub const Options = struct {
    w: *std.Io.Writer,
    log: *std.Io.Writer,
    rand: std.Random,

    aspect_ratio: f64 = 1.0,
    image_width: u16 = 100,
    samples_per_pixel: u16 = 10,
    max_bounce_depth: u16 = 10,
    vertical_fov: f64 = 90.0,
    look_from: Point = .{ 0.0, 0.0, 0.0 },
    look_at: Point = .{ 0.0, 0.0, -1.0 },
    view_up: Vec3 = .{ 0.0, 1.0, 0.0 },
    defocus_angle: f64 = 0.0,
    focus_dist: f64 = 10.0,
};

pub fn init(opts: Options) Camera {
    const w = opts.w;
    const log = opts.log;
    const rand = opts.rand;

    const aspect_ratio = opts.aspect_ratio;
    const image_width = opts.image_width;
    const image_height: u16 = @max(1, @as(u16, @intFromFloat(@as(f64, @floatFromInt(image_width)) / aspect_ratio)));
    const max_bounce_depth = opts.max_bounce_depth;

    const pixel_samples_scale: f64 = 1.0 / @as(f64, @floatFromInt(opts.samples_per_pixel));
    const samples_per_pixel = opts.samples_per_pixel;

    const center = opts.look_from;

    // Viewport dimensions
    const theta = degreesToRadians(opts.vertical_fov);
    const h = @tan(theta / 2.0);
    const viewport_height = 2.0 * h * opts.focus_dist;
    const viewport_width = viewport_height * (@as(f64, @floatFromInt(image_width)) / image_height);

    // Find basis vectors u, v, w for the camera coordinate frame.
    const cam_w = vec.unit(opts.look_from - opts.look_at);
    const cam_u = vec.unit(vec.cross(opts.view_up, cam_w));
    const cam_v = vec.cross(cam_w, cam_u);

    const viewport_u = vec.scale(cam_u, viewport_width);
    const viewport_v = vec.scale(cam_v, -viewport_height);

    const pixel_delta_u = viewport_u / vec.splat(image_width);
    const pixel_delta_v = viewport_v / vec.splat(image_height);

    // Calculate postion of top left.
    const viewport_upper_left = center - vec.scale(cam_w, opts.focus_dist) - vec.scale(viewport_u + viewport_v, 0.5);
    const pixel00 = viewport_upper_left + vec.scale(pixel_delta_u + pixel_delta_v, 0.5);

    const defocus_angle = opts.defocus_angle;
    const defocus_radius = opts.focus_dist * @tan(degreesToRadians(defocus_angle / 2.0));
    const defocus_disk_u = vec.scale(cam_u, defocus_radius);
    const defocus_disk_v = vec.scale(cam_v, defocus_radius);

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
        .defocus_angle = defocus_angle,
        .defocus_disk_u = defocus_disk_u,
        .defocus_disk_v = defocus_disk_v,
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

    var origin = self.center;
    if (self.defocus_angle > 0.0) {
        origin = self.defocusDiskSample();
    }

    const direction = pixel_sample - origin;
    return .{ .origin = origin, .direction = direction };
}

fn rayColor(self: Camera, ray: Ray, world: Hittable, depth: u16) Color {
    if (depth >= self.max_bounce_depth) {
        return .{ 0.0, 0.0, 0.0 };
    }

    const rec = world.hit(ray, 0.001, std.math.inf(f64));
    if (rec.is_hit) {
        const scatter = rec.material.scatter(ray, rec, self.rand);
        if (scatter.is_scattered) {
            return scatter.attenuation * self.rayColor(scatter.scattered, world, depth + 1);
        }
        return Color{ 0.0, 0.0, 0.0 };
    }
    // TODO: Make this work in a non bad way.
    //const unit_direction = vec.unit(r.direction);
    const unit_direction = ray.direction / vec.unit(ray.direction);
    const a = 0.5 * (unit_direction[1] + 1.0);
    return Color{ 1.0, 1.0, 1.0 } * vec.splat(1.0 - a) + Color{ 0.5, 0.7, 1.0 } * vec.splat(a);
}

fn defocusDiskSample(self: Camera) Point {
    const p = vec.randomInUnitDisk(self.rand);
    return self.center + vec.scale(self.defocus_disk_u, p[0]) + vec.scale(self.defocus_disk_v, p[1]);
}

fn degreesToRadians(degrees: f64) f64 {
    return degrees * std.math.pi / 180.0;
}
