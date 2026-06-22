const std = @import("std");

const vec = @import("vec.zig");
const Color = vec.Color;

const Ray = @import("Ray.zig");

const hittable = @import("hittable.zig");
const HitRecord = hittable.HitRecord;

const texture = @import("texture.zig");
const Texture = texture.Texture;

pub const Scatter = struct {
    attenuation: Color,
    scattered: Ray,
    is_scattered: bool,
};

pub const Material = union(enum) {
    lambertian: Lambertian,
    metal: Metal,
    dielectric: Dielectric,

    pub fn scatter(self: Material, ray_in: Ray, rec: HitRecord, rand: std.Random) Scatter {
        return switch (self) {
            .lambertian => |l| l.scatter(ray_in, rec, rand),
            .metal => |m| m.scatter(ray_in, rec, rand),
            .dielectric => |d| d.scatter(ray_in, rec, rand),
        };
    }
};

pub const Lambertian = struct {
    texture: *Texture,

    pub fn fromColor(allocator: std.mem.Allocator, color: Color) !Lambertian {
        const text = try allocator.create(Texture);
        text.* = .{ .solid_color = .{.color = color} };
        return .{ .texture = text };
    }

    pub fn scatter(self: Lambertian, ray_in: Ray, rec: HitRecord, rand: std.Random) Scatter {
        var scatter_direction = rec.normal + vec.randomUnitVec(rand);
        // Degenerate case when random vec cancels rec.normal entirely.
        if (vec.nearZero(scatter_direction)) {
            scatter_direction = rec.normal;
        }
        const scattered = Ray{ .origin = rec.point, .direction = scatter_direction, .time = ray_in.time };
        const attenuation = self.texture.value(rec.u, rec.v, rec.point);

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
        const scattered = Ray{ .origin = rec.point, .direction = reflected, .time = ray_in.time };
        const attenuation = self.albedo;
        return .{
            .attenuation = attenuation,
            .scattered = scattered,
            .is_scattered = (vec.dot(scattered.direction, rec.normal) > 0),
        };
    }
};

const Dielectric = struct {
    refraction_index: f64,

    pub fn scatter(self: Dielectric, ray_in: Ray, rec: HitRecord, rand: std.Random) Scatter {
        _ = rand;
        var refraction_index = self.refraction_index;
        if (rec.front_face) {
            refraction_index = 1.0 / refraction_index;
        }

        const unit_direction = vec.unit(ray_in.direction);

        const cos_theta = @min(vec.dot(-unit_direction, rec.normal), 1.0);
        const sin_theta = @sqrt(1.0 - cos_theta * cos_theta);

        const cannot_refract = (refraction_index * sin_theta > 1.0);
        var refracted: vec.Vec3 = undefined;
        if (cannot_refract) {
            refracted = vec.reflect(unit_direction, rec.normal);
        } else {
            refracted = vec.refract(unit_direction, rec.normal, refraction_index);
        }
        return .{
            .attenuation = .{ 1.0, 1.0, 1.0 },
            .scattered = .{ .origin = rec.point, .direction = refracted, .time = ray_in.time },
            .is_scattered = true,
        };
    }

    fn reflectance(cosine: f64, refraction_index: f64) f64 {
        var r0 = (1 - refraction_index) / (1 + refraction_index);
        r0 = r0 * r0;
        return r0 + (1 - r0) * std.math.pow(f64, (1 - cosine), 5);
    }
};
