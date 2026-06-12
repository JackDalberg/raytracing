const std = @import("std");

const Ray = @import("Ray.zig");

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

pub fn hit(self: HitList, r: Ray, t_min: f64, t_max: f64) hittable.HitRecord {
    var hr: hittable.HitRecord = .{ .is_hit = false, .time = t_max };
    for (self.list.items) |candidate| {
        const possible_hr = candidate.hit(r, t_min, t_max);
        if (possible_hr.is_hit and possible_hr.time < hr.time) {
            hr = possible_hr;
        }
    }
    return hr;
}
