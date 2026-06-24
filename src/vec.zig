const std = @import("std");

pub const Vec3 = @Vector(3, f32);
pub const Point = @Vector(3, f32);
pub const Color = @Vector(3, f32);

pub fn writeColor(w: *std.Io.Writer, color: Color) !void {
    const gamma_r = @sqrt(color[0]);
    const gamma_g = @sqrt(color[1]);
    const gamma_b = @sqrt(color[2]);

    const r = @as(u8, @intFromFloat(255.0 * @min(1.0, @max(0.0, gamma_r))));
    const g = @as(u8, @intFromFloat(255.0 * @min(1.0, @max(0.0, gamma_g))));
    const b = @as(u8, @intFromFloat(255.0 * @min(1.0, @max(0.0, gamma_b))));
    try w.print("{} {} {}\n", .{ r, g, b });
}

pub fn len(v: Vec3) f32 {
    return @sqrt(dot(v, v));
}

pub inline fn dot(v1: Vec3, v2: Vec3) f32 {
    return @reduce(.Add, v1 * v2);
}

pub fn cross(v1: Vec3, v2: Vec3) Vec3 {
    return .{
        v1[1] * v2[2] - v1[2] * v2[1],
        v1[2] * v2[0] - v1[0] * v2[2],
        v1[0] * v2[1] - v1[1] * v2[0],
    };
}

pub fn unit(v: Vec3) Vec3 {
    return v / splat(len(v));
}

pub fn scale(v: Vec3, factor: f32) Vec3 {
    return v * splat(factor);
}

pub fn splat(n: f32) Vec3 {
    return @splat(n);
}

// Returns a random Vec3 in [-1.0, 1.0) * 3
// Technically a little biased... oh well
pub fn randomVec(rand: std.Random) Vec3 {
    return .{
        1.0 - 2.0 * rand.float(f32),
        1.0 - 2.0 * rand.float(f32),
        1.0 - 2.0 * rand.float(f32),
    };
}

pub fn randomUnitVec(rand: std.Random) Vec3 {
    var r = randomVec(rand);
    if (1e-150 >= len(r)) {
        r += .{ rand.float(f32), rand.float(f32), rand.float(f32) };
    }
    return scale(r, rand.float(f32) / len(r));
}

pub fn randomOnHemisphere(rand: std.Random, normal: Vec3) Vec3 {
    const on_unit_sphere = randomUnitVec(rand);
    if (dot(on_unit_sphere, normal) > 0.0) {
        return on_unit_sphere;
    }
    return -on_unit_sphere;
}

pub fn randomInUnitDisk(rand: std.Random) Point {
    const p = Vec3{ 2.0 * rand.float(f32) - 1.0, 2.0 * rand.float(f32) - 1.0, 0.0 };
    return scale(p, rand.float(f32) / len(p));
}

pub fn nearZero(vec: Vec3) bool {
    const epsilon = 1e-8;
    return (-epsilon < vec[0] and vec[0] < epsilon) and (-epsilon < vec[1] and vec[1] < epsilon) and (-epsilon < vec[2] and vec[2] < epsilon);
}

pub fn reflect(vec: Vec3, normal: Vec3) Vec3 {
    return vec - scale(normal, 2 * dot(vec, normal));
}

pub fn refract(vec: Vec3, normal: Vec3, eta_ratio: f32) Vec3 {
    const cos_theta = @min(dot(-vec, normal), 1.0);
    const ray_out_perp = scale(vec + scale(normal, cos_theta), eta_ratio);
    const ray_out_parallel = scale(normal, -@sqrt(@abs(1.0 - dot(ray_out_perp, ray_out_perp))));
    return ray_out_perp + ray_out_parallel;
}
