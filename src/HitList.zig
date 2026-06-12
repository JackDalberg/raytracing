const std = @import("std");

const ray = @import("ray.zig");

const hittable = @import("hittable.zig");

pub const HitList = @This();

allocator: std.mem.Allocator,
list: std.ArrayList(hittable.Hittable),

pub fn init(allocator: std.mem.Allocator) !HitList {
    return .{
        .allocator = allocator,
        .list = try std.ArrayList(hittable.Hittable).initCapacity(allocator, 10),
    };
}

pub fn deinit(self: *HitList) void {
    self.list.deinit(self.allocator);
}

pub fn append(self: *HitList, item: hittable.Hittable) !void {
    try self.list.append(self.allocator, item);
}

pub fn hit(self: HitList, r: ray.Ray, t_min: f64, t_max: f64) hittable.HitRecord {
    for (self.list.items) |candidate| {
        const hl = candidate.hit(r, t_min, t_max);
        if (hl.is_hit) {
            return hl;
        }
    }
    return .{ .is_hit = false };
}
