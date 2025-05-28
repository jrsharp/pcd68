const std = @import("std");
const os = std.os;
const Builder = std.build.Builder;
const CrossTarget = std.zig.CrossTarget;
const Mode = std.builtin.Mode;
const fs = std.fs;

pub fn build(b: *std.Build) void {
    // Standard target options
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Should we build for the web?
    const build_web = b.option(bool, "build-web", "Enable web build with Emscripten") orelse false;

    // Create Moira library
    const moira_lib = b.addStaticLibrary(.{
        .name = "moira",
        .target = target,
        .optimize = optimize,
    });
    moira_lib.linkLibCpp();
    moira_lib.addCSourceFiles(.{
        .files = &.{ "src/Moira/Moira.cpp", "src/Moira/MoiraDebugger.cpp" },
        .flags = &.{},
    });

    // Create PCD68 executable
    const exe = b.addExecutable(.{
        .name = "pcd68",
        .target = target,
        .optimize = optimize,
    });
    exe.linkLibrary(moira_lib);
    exe.linkLibCpp();

    // Add include paths
    exe.addIncludePath(.{ .cwd_relative = "." });

    // SDL2 paths - use system SDL2
    if (target.result.os.tag == .macos) {
        // macOS paths
        exe.addIncludePath(.{ .cwd_relative = "/opt/homebrew/include" });
        exe.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/lib" });
    } else {
        // Linux/other paths
        exe.addIncludePath(.{ .cwd_relative = "/usr/include" });
        exe.addLibraryPath(.{ .cwd_relative = "/usr/lib" });
    }

    exe.linkSystemLibrary("SDL2");

    // Add source files
    exe.addCSourceFiles(.{
        .files = &.{ "src/PCD68_CPU.cpp", "src/main.cpp", "src/TDA.cpp", "src/KCTL.cpp", "src/UART.cpp", "src/Screen.cpp", "src/Screen_SDL.cpp", "src/KeyboardInput.cpp", "src/KeyboardInputSDL.cpp", "src/KeyboardInputEmscripten.cpp" },
        .flags = &.{ "-std=c++17", "-Wno-narrowing", "-DUSE_SDL=1" },
    });

    // Install executable
    b.installArtifact(exe);

    // Web build using Emscripten
    if (build_web) {
        // Create web output directory
        const web_dir = "zig-out/web";
        const mkdir_cmd = b.addSystemCommand(&.{ "mkdir", "-p", web_dir });

        // Copy CSS and image files
        const cp_css = b.addSystemCommand(&.{ "cp", "src/emscripten/pcd68-home.css", web_dir });
        cp_css.step.dependOn(&mkdir_cmd.step);

        const cp_img = b.addSystemCommand(&.{ "cp", "src/emscripten/FRST1_Homepage_bg.png", web_dir });
        cp_img.step.dependOn(&cp_css.step);

        // Copy ROM files
        const cp_roms = b.addSystemCommand(&.{ "mkdir", "-p", b.fmt("{s}/roms", .{web_dir}) });
        cp_roms.step.dependOn(&cp_img.step);

        // Copy jonsharp.net/program.bin (main ROM) to both locations:
        // 1. As text_demo.bin (one of the options in the ROM selector)
        // 2. Embedded into the app as the default ROM
        const cp_rom1 = b.addSystemCommand(&.{ "cp", "jonsharp.net/program.bin", b.fmt("{s}/roms/text_demo.bin", .{web_dir}) });
        cp_rom1.step.dependOn(&cp_roms.step);

        // Also make this ROM available as text_demo.h for internal embedding
        // Use xxd to convert binary to C array
        const cp_pcd68home = b.addSystemCommand(&.{ "xxd", "-i", "jonsharp.net/program.bin", "src/text_demo.h" });
        cp_pcd68home.step.dependOn(&cp_rom1.step);

        // Fix the variable name in the header file
        const fix_var_name = b.addSystemCommand(&.{ "sed", "-i", "''", "-e", "s/jonsharp_net_program_bin/text_demo_bin/g", "src/text_demo.h" });
        fix_var_name.step.dependOn(&cp_pcd68home.step);

        // Fix the length variable name in the header file
        const fix_len_name = b.addSystemCommand(&.{ "sed", "-i", "''", "-e", "s/jonsharp_net_program_bin_len/text_demo_bin_len/g", "src/text_demo.h" });
        fix_len_name.step.dependOn(&fix_var_name.step);

        // Copy other test ROMs
        //const cp_rom2 = b.addSystemCommand(&.{ "cp", "uart_test.bin", b.fmt("{s}/roms/", .{web_dir}) });
        //cp_rom2.step.dependOn(&fix_len_name.step);

        //const cp_rom3 = b.addSystemCommand(&.{ "cp", "display_test.bin", b.fmt("{s}/roms/", .{web_dir}) });
        //cp_rom3.step.dependOn(&cp_rom2.step);

        //const cp_rom4 = b.addSystemCommand(&.{ "cp", "keyboard_test.bin", b.fmt("{s}/roms/", .{web_dir}) });
        //cp_rom4.step.dependOn(&cp_rom3.step);

        // Invoke Emscripten
        const output_html = b.fmt("{s}/pcd68.html", .{web_dir});
        const emcc = b.addSystemCommand(&.{
            "em++",
            "-Wno-c++11-narrowing",
            "-O3",
            "-flto",
            "-ffast-math",
            "-DNDEBUG",
            "-std=c++17",
            "src/PCD68_CPU.cpp",
            "src/KCTL.cpp",
            "src/UART.cpp",
            "src/Screen.cpp",
            "src/Screen_SDL.cpp",
            "src/TDA.cpp",
            "src/main.cpp",
            "src/Moira/Moira.cpp",
            "src/Moira/MoiraDebugger.cpp",
            "src/KeyboardInput.cpp",
            "src/KeyboardInputSDL.cpp",
            "src/KeyboardInputEmscripten.cpp",
            "--shell-file",
            "src/emscripten/shell.html",
            "-o",
            output_html,
            "-sUSE_SDL=2",
            "-sUSE_WEBGL2=1",
            "-sUSE_PTHREADS=1",
            "-sASYNCIFY",
            "-sWEBSOCKET_DEBUG=0",
            "-sMIN_WEBGL_VERSION=2",
            "-sALLOW_MEMORY_GROWTH=1",
            "-sWASM=1",
            "-sFETCH=1",
            "-sASSERTIONS=0",
            "-sMALLOC=emmalloc",
            "-lwebsocket",
            "-sWEBSOCKET_URL=\"ws://\"",
            "-sWEBSOCKET_SUBPROTOCOL=\"binary\"",
            "-sEXPORTED_FUNCTIONS=['_malloc','_free','_main','_loadExternalRom','_loadInternalRom']",
            "-sEXPORTED_RUNTIME_METHODS=['ccall','cwrap']",
        });
        emcc.step.dependOn(&fix_len_name.step);

        // Add to the install step
        b.getInstallStep().dependOn(&emcc.step);

        std.log.info("Building web build of PCD-68", .{});
    }

    // Create run command
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Create test step
    const test_step = b.step("test", "Run tests");
    const test_exe = b.addExecutable(.{
        .name = "pcd68_test",
        .root_source_file = null,
        .target = target,
        .optimize = optimize,
    });
    test_exe.addCSourceFiles(.{
        .files = &.{"src/TestPeripheral.cpp"},
        .flags = &.{"-std=c++17"},
    });
    test_exe.addCSourceFiles(.{
        .files = &.{"src/PCD68_CPU.cpp"},
        .flags = &.{"-std=c++17"},
    });
    test_exe.linkLibCpp();
    test_exe.linkLibrary(moira_lib);
    test_exe.linkSystemLibrary("gtest");

    const test_cmd = b.addRunArtifact(test_exe);
    test_step.dependOn(&test_cmd.step);
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
