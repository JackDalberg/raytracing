const std = @import("std");

const vec = @import("vec.zig");
const Color = vec.Color;

const Ray = @import("Ray.zig");

const hittable = @import("hittable.zig");
const HitRecord = hittable.HitRecord;

pub const Scatter = struct {
    attenuation: Color,
    scattered: Ray,
    is_scattered: bool,
};

pub const Material = union(enum) {
    lambertian: Lambertian,
    metal: Metal,

    pub fn scatter(self: Material, ray_in: Ray, rec: HitRecord, rand: std.Random) Scatter {
        return switch (self) {
            .lambertian => |l| l.scatter(ray_in, rec, rand),
            .metal => |m| m.scatter(ray_in, rec, rand),
        };
    }
};

const Lambertian = struct {
    albedo: Color,

    pub fn scatter(self: Lambertian, ray_in: Ray, rec: HitRecord, rand: std.Random) Scatter {
        _ = ray_in;
        var scatter_direction = rec.normal + vec.randomUnitVec(rand);
        // Degenerate case when random vec cancels rec.normal entirely.
        if (vec.nearZero(scatter_direction)) {
            scatter_direction = rec.normal;
        }
        const scattered = Ray{ .origin = rec.point, .direction = scatter_direction };
        const attenuation = self.albedo;

        return .{
            .attenuation = attenuation,
            .scattered = scattered,
            .is_scattered = true,
        };
    }
};

const Metal = struct {
    albedo: Color,
    fuzz: f64,

    pub fn init(albedo: Color, fuzz: f64) Metal {
        return .{
            .albedo = albedo,
            .fuzz = @min(1.0, fuzz),
        };
    }

    pub fn scatter(self: Metal, ray_in: Ray, rec: HitRecord, rand: std.Random) Scatter {
        var reflected = vec.reflect(ray_in.direction, rec.normal);
        reflected = vec.unit(reflected) + vec.scale(vec.randomUnitVec(rand), self.fuzz);
        const scattered = Ray{ .origin = rec.point, .direction = reflected };
        const attenuation = self.albedo;
        return .{
            .attenuation = attenuation,
            .scattered = scattered,
            .is_scattered = (vec.dot(scattered.direction, rec.normal) > 0),
        };
    }
};
