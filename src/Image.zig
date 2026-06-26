const std = @import("std");
const ArrayList = std.ArrayList;

const vec = @import("vec.zig");
const Color = vec.Color;

// In pixels.
width: u32,
height: u32,
pixels: ArrayList(Color),

const Image = @This();

const ImageType = enum {
    ppm,
};

const ImageError = error{
    InvalidHeader,
    InvalidFileFormat,
    // Too many colors since we assume 0-255 only.
    TooManyColors,
};

pub fn init(io: std.Io, allocator: std.mem.Allocator, file_type: ImageType, file_name: []const u8) !Image {
    switch (file_type) {
        .ppm => {
            // P3\n
            // image_width image_height\n
            // 255\n
            // R G B\n
            // R G B\n...
            const cwd = std.Io.Dir.cwd();
            const file = try cwd.openFile(io, file_name, .{});
            defer file.close(io);

            var read_buf: [1024]u8 = undefined;

            var file_reader = file.reader(io, &read_buf);
            const reader = &file_reader.interface;

            var line_buffer = std.Io.Writer.Allocating.init(allocator);
            defer line_buffer.deinit();

            _ = try reader.streamDelimiter(&line_buffer.writer, '\n');
            const header = line_buffer.written();
            if (!std.mem.eql(u8, "P3", header)) {
                return ImageError.InvalidHeader;
            }
            line_buffer.clearRetainingCapacity();
            reader.toss(1);

            _ = try reader.streamDelimiter(&line_buffer.writer, '\n');
            const image_dim = line_buffer.written();
            var idx: usize = 0;
            while (image_dim[idx] != ' ') {
                idx += 1;
            }
            const image_width = try std.fmt.parseInt(u32, image_dim[0..idx], 10);
            while (image_dim[idx] == ' ') {
                idx += 1;
            }
            const image_height = try std.fmt.parseInt(u32, image_dim[idx..], 10);
            line_buffer.clearRetainingCapacity();
            reader.toss(1);

            _ = try reader.streamDelimiter(&line_buffer.writer, '\n');
            const colors = line_buffer.written();
            if (!std.mem.eql(u8, "255", colors)) {
                return ImageError.TooManyColors;
            }
            line_buffer.clearRetainingCapacity();
            reader.toss(1);

            var total_pixels: u32 = 0;
            const image_size = image_width * image_height;
            var color_list = try ArrayList(Color).initCapacity(allocator, image_width * image_height);
            while (true) {
                if (total_pixels > image_size) {
                    return ImageError.InvalidFileFormat;
                }
                _ = reader.streamDelimiter(&line_buffer.writer, '\n') catch |err| switch (err) {
                    error.EndOfStream => break,
                    else => return err,
                };
                const rgb = line_buffer.written();
                const color = try parseColor(rgb);
                try color_list.append(allocator, color);

                line_buffer.clearRetainingCapacity();
                reader.toss(1);
                total_pixels += 1;
            }

            return .{
                .width = image_width,
                .height = image_height,
                .pixels = color_list,
            };
        },
    }
}

pub fn deinit(self: *Image, allocator: std.mem.Allocator) void {
    self.pixels.deinit(allocator);
}

pub fn pixelColor(self: Image, x: u32, y: u32) Color {
    return self.pixels.items[(self.height - y) * self.width + x];
}

// Expects rbg to be of the form "ddd ddd ddd"
// where "d" is a digit 0-9 or not there
// ex: "255 1 90"
fn parseColor(rgb: []u8) !Color {
    var idx1: usize = 0;
    var idx2: usize = 0;
    while (rgb[idx2] != ' ') {
        idx2 += 1;
    }
    const r = try std.fmt.parseInt(u8, rgb[idx1..idx2], 10);
    while (rgb[idx2] == ' ') {
        idx2 += 1;
    }
    idx1 = idx2;
    while (rgb[idx2] != ' ') {
        idx2 += 1;
    }
    const g = try std.fmt.parseInt(u8, rgb[idx1..idx2], 10);
    while (rgb[idx2] == ' ') {
        idx2 += 1;
    }
    idx1 = idx2;
    const b = try std.fmt.parseInt(u8, rgb[idx1..], 10);
    return .{
        @as(f32, @floatFromInt(r)) / 255.0,
        @as(f32, @floatFromInt(g)) / 255.0,
        @as(f32, @floatFromInt(b)) / 255.0,
    };
}
