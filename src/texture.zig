const vec = @import("vec.zig");
const Color = vec.Color;
const Point = vec.Point;

const Image = @import("Image.zig");

pub const Texture = union(enum) {
    // Single types.
    solid_color: Solid,
    image: ImageTexture,
    // Aggregate types.
    checker: Checker,

    pub fn value(self: Texture, u: f64, v: f64, point: Point) Color {
        return switch (self) {
            .solid_color => |s| s.value(u, v, point),
            .checker => |c| c.value(u, v, point),
            .image => |i| i.value(u, v, point),
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

pub const ImageTexture = struct {
    image: *Image,

    pub fn value(self: ImageTexture, u: f64, v: f64, _: Point) Color {
        if (self.image.height == 0) {
            return .{0.0, 1.0, 1.0};
        }

        const clamp_u = @max(0.0, @min(1.0, u));
        const clamp_v = @max(0.0, @min(1.0, v));

        const i: u32 = @intFromFloat(clamp_u * @as(f64, @floatFromInt(self.image.width)));
        const j: u32 = @intFromFloat(clamp_v * @as(f64, @floatFromInt(self.image.height)));
        const pixel = self.image.pixelColor(i, j);
        return pixel;
    }
};
