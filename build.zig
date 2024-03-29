const std = @import("std");
const os = std.os;
const Builder = std.build.Builder;
const CrossTarget = std.zig.CrossTarget;
const Mode = std.builtin.Mode;
const fs = std.fs;

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
    pcd68.addIncludeDir(".");
    pcd68.addIncludeDir(sdl_include_path);
    pcd68.addLibPath(sdl_lib_path);
    pcd68.linkLibrary(moiraLib);
    pcd68.linkSystemLibrary("sdl2");
    pcd68.linkLibCpp();

    // Should we build for the web, too?
    var env = std.process.getEnvMap(b.allocator) catch unreachable;
    const build_web = env.get("BUILD_WEB");
    if (build_web) |bw| {
        std.fs.cwd().makePath("zig-out/web") catch |err| {
            std.log.err("{s}", .{err});
        };

        // Need CSS and image
        const cpCss = b.addSystemCommand(&.{ "cp", "src/emscripten/pcd68-home.css", "zig-out/web" });
        b.getInstallStep().dependOn(&cpCss.step);
        const cpImg = b.addSystemCommand(&.{ "cp", "src/emscripten/FRST1_Homepage_bg.png", "zig-out/web" });
        b.getInstallStep().dependOn(&cpImg.step);

        std.log.info("Building web build of PCD-68 since BUILD_WEB is set to ({s})", .{bw});
        // Invoke em++ entirely externally
        const emcc = b.addSystemCommand(&.{ "em++", "-Wno-c++11-narrowing", "-O2", "-flto", "-std=c++17", "src/CPU.cpp", "src/KCTL.cpp", "src/Screen.cpp", "src/Screen_SDL.cpp", "src/TDA.cpp", "src/main.cpp", "src/Moira/Moira.cpp", "src/Moira/MoiraDebugger.cpp", "--shell-file", "src/emscripten/shell.html", "-ozig-out/web/pcd68.html", "-sUSE_SDL=2", "-sUSE_WEBGL2=1", "-sUSE_PTHREADS=1", "-sASYNCIFY" });

        // get the emcc step to run on 'zig build'
        b.getInstallStep().dependOn(&emcc.step);
    }

    if (pcd68.target.getCpuArch() == .wasm32) {
        pcd68.defineCMacro("USE_SDL", "2");
        pcd68.defineCMacro("USE_PTHREADS", "1");
        pcd68.addCSourceFiles(&.{ "src/CPU.cpp", "src/main.cpp", "src/TDA.cpp", "src/KCTL.cpp", "src/Screen.cpp" }, &.{ "-std=c++17", "-Wno-narrowing", "-pthread", "-DUSE=SDL=2", "-DUSE_PTHREADS=1" });
        pcd68.addCSourceFile("src/Screen_SDL.cpp", &[_][]const u8{});
    } else {
        pcd68.defineCMacro("USE_SDL", "1");
        pcd68.addCSourceFiles(&.{ "src/CPU.cpp", "src/main.cpp", "src/TDA.cpp", "src/KCTL.cpp", "src/Screen.cpp" }, &.{ "-std=c++17", "-Wno-narrowing" });
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

//fn buildWasm(b: *Builder, target: CrossTarget, mode: Mode) !void {
fn buildWasm(b: *Builder, target: CrossTarget) !void {
    if (b.sysroot == null) {
        std.log.err("Please build with 'zig build -Dtarget=wasm32-emscripten --sysroot [path/to/emsdk]/upstream/emscripten/cache/sysroot", .{});
        return error.SysRootExpected;
    }

    // derive the emcc and emrun paths from the provided sysroot:
    const emcc_path = try fs.path.join(b.allocator, &.{ b.sysroot.?, "../../emcc" });
    defer b.allocator.free(emcc_path);
    const emrun_path = try fs.path.join(b.allocator, &.{ b.sysroot.?, "../../emrun" });
    defer b.allocator.free(emrun_path);

    // for some reason, the sysroot/include path must be provided separately
    const include_path = try fs.path.join(b.allocator, &.{ b.sysroot.?, "include" });
    defer b.allocator.free(include_path);

    // sokol must be built with wasm32-emscripten
    var wasm32_emscripten_target = target;
    wasm32_emscripten_target.os_tag = .emscripten;

    // the game code must be build as library with wasm32-freestanding
    var wasm32_freestanding_target = target;
    wasm32_freestanding_target.os_tag = .freestanding;

    // call the emcc linker step as a 'system command' zig build step which
    // depends on the libsokol and libgame build steps
    try fs.cwd().makePath("zig-out/web");
    const emcc = b.addSystemCommand(&.{
        emcc_path,
        "-Os",
        "--closure",
        "1",
        "src/emscripten/entry.c",
        "-ozig-out/web/pacman.html",
        "--shell-file",
        "src/emscripten/shell.html",
        "-Lzig-out/lib/",
        "-lgame",
        "-lsokol",
        "-sNO_FILESYSTEM=1",
        "-sMALLOC='emmalloc'",
        "-sASSERTIONS=0",
        "-sEXPORTED_FUNCTIONS=['_malloc','_free','_main']",
    });

    // get the emcc step to run on 'zig build'
    b.getInstallStep().dependOn(&emcc.step);

    // a seperate run step using emrun
    const emrun = b.addSystemCommand(&.{ emrun_path, "zig-out/web/pcd68.html" });
    emrun.step.dependOn(&emcc.step);
    b.step("run", "Run pcd68").dependOn(&emrun.step);
}
