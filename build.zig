const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    b.enable_wasmtime = true;

    const target = b.standardTargetOptions(.{});
    //const mode = std.builtin.Mode.Debug;

    const moiraLib = b.addStaticLibrary("moira", null);
    moiraLib.setTarget(target);
    moiraLib.setBuildMode(.Debug);
    moiraLib.linkLibCpp();
    moiraLib.addCSourceFiles(&.{ "src/Moira/Moira.cpp", "src/Moira/MoiraDebugger.cpp" }, &.{});

    const sdl_lib_path = "/opt/homebrew/lib";
    const sdl_include_path = "/opt/homebrew/include";
    const pcd68 = b.addExecutable("pcd68", null);
    pcd68.setTarget(target);
    pcd68.setBuildMode(.Debug);
    pcd68.install();
    pcd68.addIncludeDir(sdl_include_path);
    pcd68.addLibPath(sdl_lib_path);
    pcd68.linkLibrary(moiraLib);
    pcd68.linkSystemLibrary("sdl2");
    pcd68.linkLibCpp();

    if (pcd68.target.getCpuArch() == .wasm32) {
        pcd68.defineCMacro("USE_SDL", "0");
        pcd68.addCSourceFiles(&.{ "src/CPU.cpp", "src/main.cpp", "src/TDA.cpp" }, &.{ "-std=c++17", "-D_WASI_EMULATED_SIGNAL", "-lwasi-emulated-signal", "-DUSE_PTHREADS=1" });
        pcd68.addCSourceFile("src/Screen_Memory.cpp", &[_][]const u8{});
    } else {
        pcd68.defineCMacro("USE_SDL", "1");
        pcd68.addCSourceFiles(&.{ "src/CPU.cpp", "src/main.cpp", "src/TDA.cpp" }, &.{"-std=c++17"});
        pcd68.addCSourceFile("src/Screen_SDL.cpp", &[_][]const u8{});
    }

    const test_step = b.step("test", "Runs the test suite");
    {
        //const test_suite = b.addTest("src/tests.zig");
        const test_suite = b.addTest("src/TestPeripheral.cpp");
        test_suite.addCSourceFiles(&.{"src/CPU.cpp"}, &.{"-std=c++17"});
        test_suite.linkSystemLibrary("gtest");
        test_suite.linkLibrary(moiraLib);
        test_suite.linkLibC();
        test_suite.linkLibCpp();
        test_step.dependOn(&test_suite.step);
    }
}
