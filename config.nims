task build, "Builds debug version":
    var outName : string

    when defined(windows):
      outName = "dist/pokey.exe"
    else:
      outName = "dist/pokey"

    setCommand "cpp", "src/pokey"

    # Debuggery
    --debuginfo:on
    --debugger:native
    --stackTrace:on
    --lineTrace:on

    # Profiling - uncomment import nimprof line in nif.nim.
    #--profiler:on
    #--stacktrace:on

    # memory profiling - uncomment import nimprof line in nif.nim.
#   --profiler:off
#   --define: memProfiler
#   --stacktrace:on

    --listFullPaths
    --threads:on
    --threadAnalysis:on
    --define: debug

    --warnings:on
    --hints:on
    --colors:off
    --nanChecks:on
    --infChecks:on
    --overflowChecks:on  # This is expensive for what we're doing.

    #--gc:arc

    switch("path", "src")
    switch("path", "vendor/sdl2/src")
    switch("path", "vendor/opengl/src")
    switch("path", "vendor/x11")
    switch("path", "commonlib")
    switch("out", outName)

