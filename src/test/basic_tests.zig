const std = @import("std");
const moira = @cImport({
    @cInclude("moira.h");
});
const pcd68 = @cImport({
    @cInclude("CPU.h");
    @cInclude("Peripheral.h");
});

export var systemRom: [1024]i8 = undefined;
export var systemRam: [1024 * 1024]i8 = undefined;
export var clocks: i64 = 0;

test "Peripheral.isValidForCorrectValue" {
    try expect(true == 65);
}

const expect = std.testing.expect;
