const std = @import("std");

pub const MemoryPool = struct {
    allocator: std.mem.Allocator,
    current_block: *Block,
    block_size: usize,

    const Block = struct {
        data: []u8,
        used: usize,
        next: ?*Block,
    };

    pub fn init(allocator: std.mem.Allocator, block_size: usize) !*MemoryPool {
        const pool = try allocator.create(MemoryPool);
        const first_block = try allocator.create(Block);
        first_block.* = .{
            .data = try allocator.alloc(u8, block_size),
            .used = 0,
            .next = null,
        };

        pool.* = .{
            .allocator = allocator,
            .current_block = first_block,
            .block_size = block_size,
        };
        return pool;
    }

    pub fn deinit(self: *MemoryPool) void {
        var current = self.current_block;
        while (current) |block| {
            const next = block.next;
            self.allocator.free(block.data);
            self.allocator.destroy(block);
            current = next;
        }
        self.allocator.destroy(self);
    }

    pub fn alloc(self: *MemoryPool, size: usize) ![]u8 {
        if (self.current_block.used + size > self.block_size) {
            const new_block = try self.allocator.create(Block);
            new_block.* = .{
                .data = try self.allocator.alloc(u8, self.block_size),
                .used = 0,
                .next = null,
            };
            self.current_block.next = new_block;
            self.current_block = new_block;
        }
        const result = self.current_block.data[self.current_block.used..][0..size];
        self.current_block.used += size;
        return result;
    }

    pub fn reset(self: *MemoryPool) void {
        var current = self.current_block;
        while (current) |block| {
            block.used = 0;
            current = block.next;
        }
        self.current_block = current.?;
    }
};
