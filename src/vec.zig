const std = @import("std");

pub const Vec3 = @Vector(3, f64);
pub const Point = @Vector(3, f64);
pub const Color = @Vector(3, f64);

pub fn writeColor(w: *std.Io.Writer, color: Color) !void {
    const gamma_r = @sqrt(color[0]);
    const gamma_g = @sqrt(color[1]);
    const gamma_b = @sqrt(color[2]);

    const r = @as(u8, @intFromFloat(255.999 * @min(0.99, @max(0.0, gamma_r))));
    const g = @as(u8, @intFromFloat(255.999 * @min(0.99, @max(0.0, gamma_g))));
    const b = @as(u8, @intFromFloat(255.999 * @min(0.99, @max(0.0, gamma_b))));
    try w.print("{} {} {}\n", .{ r, g, b });
}

pub inline fn vec3(n: anytype) Vec3 {
    return splat(Vec3, n);
}

pub inline fn len(v: anytype) vtype(@TypeOf(v)) {
    ensureVector(@TypeOf(v));
    return @sqrt(dot(v, v));
}

pub inline fn dot(v1: anytype, v2: anytype) vtype(@TypeOf(v1)) {
    ensureSameVector(v1, v2);
    return @reduce(.Add, v1 * v2);
}

pub inline fn cross(v1: anytype, v2: anytype) @TypeOf(v1) {
    ensureSameVector(v1, v2);
    if (vsize(v1) != 3) @compileError("cross: both vectors must be of length 3");
    return .{
        v1[1] * v2[2] - v1[2] * v2[1],
        v1[2] * v2[0] - v1[0] * v2[2],
        v1[0] * v2[1] - v1[1] * v2[0],
    };
}

pub inline fn unit(v: anytype) @TypeOf(v) {
    ensureVector(@TypeOf(v));
    return v / splat(@TypeOf(v), len(v));
}

pub inline fn scale(v: anytype, factor: anytype) @TypeOf(v) {
    ensureVector(@TypeOf(v));
    return v * splat(@TypeOf(v), factor);
}

pub inline fn splat(comptime T: type, n: anytype) T {
    ensureVector(T);
    const vt = vtype(T);
    const nt = @TypeOf(n);
    return switch (@typeInfo(nt)) {
        .comptime_float, .comptime_int, .int, .float => @splat(@as(vt, n)),
        else => @compileError("splat: not able to splat type" ++ @typeName(nt)),
    };
}

// Returns a random Vec3 in [-1.0, 1.0) * 3
// Technically a little biased... oh well
pub fn randomVec(rand: std.Random) Vec3 {
    return .{
        1.0 - 2 * rand.float(f64),
        1.0 - 2 * rand.float(f64),
        1.0 - 2 * rand.float(f64),
    };
}

pub fn randomUnitVec(rand: std.Random) Vec3 {
    while (true) {
        const r = randomVec(rand);
        const l = len(r);
        if (1e-150 < l and l <= 1.0) {
            return scale(r, len(r));
        }
    }
}

pub fn randomOnHemisphere(rand: std.Random, normal: Vec3) Vec3 {
    const on_unit_sphere = randomUnitVec(rand);
    if (dot(on_unit_sphere, normal) > 0.0) {
        return on_unit_sphere;
    }
    return -on_unit_sphere;
}

pub fn nearZero(vec: Vec3) bool {
    const epsilon = 1e-8;
    return (-epsilon < vec[0] and vec[0] < epsilon)
    and (-epsilon < vec[1] and vec[1] < epsilon)
    and (-epsilon < vec[2] and vec[2] < epsilon);
}

pub fn reflect(vec: Vec3, normal: Vec3) Vec3 {
    return vec - scale(normal, 2 * dot(vec, normal));
}

// Helper functions over the builtin Vector type to allow for generic functions on Vector types.
// See: https://github.com/ryoppippi/Ray-Tracing-in-One-Weekend.zig/blob/main/src/vec.zig.
inline fn ensureVector(comptime T: type) void {
    if (@typeInfo(T) != .vector) @compileError("ensureVector: type is not vector");
}

inline fn ensureSameVector(v1: anytype, v2: anytype) void {
    ensureVector(@TypeOf(v1));
    ensureVector(@TypeOf(v2));
    if (@TypeOf(v1) != @TypeOf(v2)) @compileError("ensureSameVector: vector type are not the same");
}

inline fn vsize(comptime T: type) comptime_int {
    ensureVector(T);
    return @typeInfo(T).vector.len;
}

inline fn vtype(comptime T: type) type {
    ensureVector(T);
    return @typeInfo(T).vector.child;
}

test "dot vec3 vec3" {
    const v1 = Vec3{ 0.0, 2.0, 3.0 };
    const v2 = Vec3{ 100.0, 20.0, 10.0 };

    const expected = 70.0;
    try std.testing.expectApproxEqRel(expected, dot(v1, v2), 0.001);
}
