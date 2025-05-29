set(srcs 
    "src/PCD68_CPU.cpp"
    "src/KCTL.cpp"
    "src/Screen.cpp"
    "src/TDA.cpp"
    "src/Moira/Moira.cpp"
    "src/Moira/MoiraDebugger.cpp"
    )

idf_component_register(SRCS ${srcs}
                        INCLUDE_DIRS "src" "src/Moira"
                        REQUIRES "CalEPD"
)

target_link_options(${COMPONENT_LIB} PUBLIC -mlongcalls -mtext-section-literals)
target_compile_options(${COMPONENT_LIB} PUBLIC -mlongcalls -mtext-section-literals)
