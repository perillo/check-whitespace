// Copyright 2022 Manlio Perillo. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//! Check incorrect whitespace, as done by git:
//!   - blank-at-eol
//!   - blank-at-eof
//!   - space-before-tab

const std = @import("std");
const ascii = std.ascii;
const fmt = std.fmt;
const fs = std.fs;
const heap = std.heap;
const io = std.io;
const mem = std.mem;
const os = std.os;
const process = std.process;

var stderr = io.getStdErr().writer();
var stdout = io.getStdOut().writer();

pub fn main() !void {
    var arena = heap.ArenaAllocator.init(heap.page_allocator);
    defer arena.deinit(); // NOTE(mperillo): Can be removed

    const allocator = arena.allocator();

    var args_it = try process.argsWithAllocator(allocator);
    _ = args_it.skip(); // it is safe to ignore

    while (args_it.next()) |path| {
        try checkWhitespace(path);
    }
}

fn checkWhitespace(path: []const u8) !void {
    var buf: [4096]u8 = undefined;

    var file = try fs.cwd().openFile(path, .{ .mode = .read_only });
    var br = io.bufferedReader(file.reader());
    const r = br.reader();
    var lineno: usize = 0;
    while (true) {
        if (try r.readUntilDelimiterOrEof(&buf, '\n')) |line| {
            lineno += 1;

            if (line.len == 0) {
                // Empty line.
                continue;
            }

            // In order to keep the code simple, print the same line for each
            // of the check.  Also, only the first issue is highlighted.

            if (ascii.isWhitespace(line[line.len - 1])) {
                // Blank at eol or eof.
                // TODO(mperillo): Add support for checking blank at eof.
                try stderr.print(
                    "{s} {:0>5} {s}{s}\n",
                    .{ path, lineno, line[0 .. line.len - 1], eprintf("<SP>") },
                );
            }

            const idx = mem.indexOfScalar(u8, line, '\t') orelse 0;
            if (idx > 0 and ascii.isWhitespace(line[idx - 1])) {
                // Space before tab.
                try stderr.print(
                    "{s} {:0>5} {s}{s}{s}\n",
                    .{ path, lineno, line[0 .. idx - 1], eprintf("<SP><TAB>"), line[idx + 1 ..] },
                );
            }
        } else {
            break;
        }
    }
}

/// Mark s as an error.
fn eprintf(comptime s: []const u8) []const u8 {
    return "\x1b[31m" ++ s ++ "\x1b[0m";
}
