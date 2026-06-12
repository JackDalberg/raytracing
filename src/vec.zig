const std = @import("std");

pub const Vec3 = @Vector(3, f64);
pub const Point = @Vector(3, f64);
pub const Color = @Vector(3, f64);

pub fn writeColor(w: *std.Io.Writer, color: Color) !void {
    const r = @as(u8, @intFromFloat(255.999 * @min(0.99, @max(0.0, color[0]))));
    const g = @as(u8, @intFromFloat(255.999 * @min(0.99, @max(0.0, color[1]))));
    const b = @as(u8, @intFromFloat(255.999 * @min(0.99, @max(0.0, color[2]))));
    try w.print("{} {} {}\n", .{ r, g, b});
}

pub inline fn vec3(n: anytype) Vec3 {
    return splat(Vec3, n);
}

pub inline fn len(v: anytype) vtype(@TypeOf(v)) {
    ensureVector(v);
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
