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

test "Peripheral.isValidForCorrectValue" {}

fn addOne(number: i32) i32 {
    return number + 1;
}
