const vec = @import("vec.zig");
const Color = vec.Color;
const Point = vec.Point;

pub const Texture = union(enum) {
    // Single types.
    solid_color: Solid,
    // Aggregate types.
    checker: Checker,

    pub fn value(self: Texture, u: f64, v: f64, point: Point) Color {
        return switch (self) {
            .solid_color => |s| s.value(u, v, point),
            .checker => |c| c.value(u, v, point),
        };
    }
};

pub const Solid = struct {
    color: Color,

    pub fn value(self: Solid, _: f64, _: f64, _: Point) Color {
        return self.color;
    }
};

pub const Checker = struct {
    even: *Texture,
    odd: *Texture,
    inverse_scale: f64,

    pub fn value(self: Checker, u: f64, v: f64, point: Point) Color {
        const x: i32 = @intFromFloat(@floor(self.inverse_scale * point[0]));
        const y: i32 = @intFromFloat(@floor(self.inverse_scale * point[1]));
        const z: i32 = @intFromFloat(@floor(self.inverse_scale * point[2]));
        const is_even = (@mod(x + y + z, 2) == 0);
        if (is_even) {
            return self.even.value(u, v, point);
        }
        return self.odd.value(u, v, point);
    }
};
