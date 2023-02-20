#!/bin/bash
set -e

# Basic definitions.
BENCHVER=20230112
LLVMVER=15.0.7
LLVMURL="https://github.com/llvm/llvm-project/releases/download/llvmorg-$LLVMVER/llvm-project-$LLVMVER.src.tar.xz"
LLVMDIR="$(basename $LLVMURL | rev | cut -f3- -d'.' | rev)"
DEPENDENCIES="devel-base"

# Autobuild3 output formatter functions.
abwarn() { echo -e "[\e[33mWARN\e[0m]: \e[1m$*\e[0m"; }
aberr()  { echo -e "[\e[31mERROR\e[0m]: \e[1m$*\e[0m"; exit 1; }
abinfo() { echo -e "[\e[96mINFO\e[0m]: \e[1m$*\e[0m"; }

# Autobuild3 dpkg handler functions.
pm_exists(){
        for p in "$@"; do
                dpkg $PM_ROOTPARAM -l "$p" | grep ^ii >/dev/null 2>&1 || return 1
        done
}
pm_repoupdate(){
        apt-get update
}
pm_repoinstall(){
        apt-get install "$@" --yes
}

echo -e "
******************************************************************************
----------------    BUILDBOT BENCHMARK (version $BENCHVER)    -----------------
******************************************************************************

Benchmark: Building LLVM runtime (version $LLVMVER), using Ninja, LTO enabled.

System architecture: $(dpkg --print-architecture)
System processors: $(nproc)
System memory: $(( $(cat /proc/meminfo | grep MemTotal | awk '{ print $2 }') / 1024 / 1024 )) GiB
"

abinfo "(1/6) Preparing to benchmark Buildbot: Fetching dependencies ..."
if ! pm_exists $DEPENDENCIES; then
    abinfo "Build or runtime dependencies not satisfied, now fetching needed packages."
    pm_repoupdate || \
        aberr "Failed to refresh repository: $?"
    pm_repoinstall $DEPENDENCIES || \
        aberr "Failed to install needed dependencies: $?"
fi

abinfo "(2/6) Preparing to benchmark Buildbot: Downloading LLVM (version $LLVMVER) ..."
wget -c $LLVMURL 2> benchmark.log || \
    aberr "Failed to download LLVM: $?."

abinfo "(3/6) Preparing to benchmark Buildbot: Unpacking LLVM (version $LLVMVER) ..."
rm -rf "$LLVMDIR"
tar xf $(basename $LLVMURL) || \
    aberr "Failed to unpack LLVM: $?."

abinfo "(4/6) Preparing to benchmark Buildbot: Setting up build environment ..."
mkdir -p "$LLVMDIR"/llvm/build || \
    aberr "Failed to create build directory: $?."
cd "$LLVMDIR"/llvm/build || \
    aberr "Failed to swtich to build directory: $?."

abinfo "(5/6) Preparing to benchmark Buildbot: Configuring LLVM (version $LLVMVER) ..."
cmake .. \
    -DBENCHMARK_BUILD_32_BITS:BOOL=OFF \
    -DBENCHMARK_DOWNLOAD_DEPENDENCIES:BOOL=OFF \
    -DBENCHMARK_ENABLE_ASSEMBLY_TESTS:BOOL=OFF \
    -DBENCHMARK_ENABLE_DOXYGEN:BOOL=OFF \
    -DBENCHMARK_ENABLE_EXCEPTIONS:BOOL=OFF \
    -DBENCHMARK_ENABLE_GTEST_TESTS:BOOL=OFF \
    -DBENCHMARK_ENABLE_INSTALL:BOOL=OFF \
    -DBENCHMARK_ENABLE_LIBPFM:BOOL=OFF \
    -DBENCHMARK_ENABLE_LTO:BOOL=OFF \
    -DBENCHMARK_ENABLE_TESTING:BOOL=OFF \
    -DBENCHMARK_ENABLE_WERROR:BOOL=OFF \
    -DBENCHMARK_FORCE_WERROR:BOOL=OFF \
    -DBENCHMARK_INSTALL_DOCS:BOOL=OFF \
    -DBENCHMARK_USE_BUNDLED_GTEST:BOOL=OFF \
    -DBENCHMARK_USE_LIBCXX:BOOL=OFF \
    -DBUG_REPORT_URL:STRING=https://github.com/llvm/llvm-project/issues/ \
    -DBUILD_SHARED_LIBS:BOOL=OFF \
    -DCMAKE_BUILD_TYPE:STRING=Release \
    -DCMAKE_CXX_STANDARD:STRING=14 \
    -DCMAKE_INSTALL_PACKAGEDIR:PATH=lib/cmake \
    -DCMAKE_INSTALL_PREFIX:PATH=/usr/local \
    -DFFI_INCLUDE_DIR:PATH= \
    -DFFI_LIBRARY_DIR:PATH= \
    -DGOLD_EXECUTABLE:FILEPATH=/bin/ld.gold \
    -DGO_EXECUTABLE:FILEPATH=/bin/go \
    -DHAVE_STD_REGEX:BOOL=ON \
    -DLLVM_ABI_BREAKING_CHECKS:STRING=WITH_ASSERTS \
    -DLLVM_ALLOW_PROBLEMATIC_CONFIGURATIONS:BOOL=OFF \
    -DLLVM_APPEND_VC_REV:BOOL=OFF \
    -DLLVM_BINUTILS_INCDIR:PATH= \
    -DLLVM_BUILD_32_BITS:BOOL=OFF \
    -DLLVM_BUILD_BENCHMARKS:BOOL=OFF \
    -DLLVM_BUILD_DOCS:BOOL=OFF \
    -DLLVM_BUILD_EXAMPLES:BOOL=OFF \
    -DLLVM_BUILD_EXTERNAL_COMPILER_RT:BOOL=OFF \
    -DLLVM_BUILD_LLVM_C_DYLIB:BOOL=OFF \
    -DLLVM_BUILD_LLVM_DYLIB:BOOL=OFF \
    -DLLVM_BUILD_RUNTIME:BOOL=ON \
    -DLLVM_BUILD_RUNTIMES:BOOL=ON \
    -DLLVM_BUILD_TESTS:BOOL=OFF \
    -DLLVM_BUILD_TOOLS:BOOL=OFF \
    -DLLVM_BUILD_UTILS:BOOL=OFF \
    -DLLVM_BYE_LINK_INTO_TOOLS:BOOL=OFF \
    -DLLVM_CCACHE_BUILD:BOOL=OFF \
    -DLLVM_CODESIGNING_IDENTITY:STRING= \
    -DLLVM_DEPENDENCY_DEBUGGING:BOOL=OFF \
    -DLLVM_DYLIB_COMPONENTS:STRING=all \
    -DLLVM_ENABLE_ASSERTIONS:BOOL=OFF \
    -DLLVM_ENABLE_BACKTRACES:BOOL=OFF \
    -DLLVM_ENABLE_BINDINGS:BOOL=OFF \
    -DLLVM_ENABLE_CRASH_DUMPS:BOOL=OFF \
    -DLLVM_ENABLE_CRASH_OVERRIDES:BOOL=OFF \
    -DLLVM_ENABLE_CURL:STRING=OFF \
    -DLLVM_ENABLE_DAGISEL_COV:BOOL=OFF \
    -DLLVM_ENABLE_DOXYGEN:BOOL=OFF \
    -DLLVM_ENABLE_DUMP:BOOL=OFF \
    -DLLVM_ENABLE_EH:BOOL=OFF \
    -DLLVM_ENABLE_EXPENSIVE_CHECKS:BOOL=OFF \
    -DLLVM_ENABLE_FFI:BOOL=OFF \
    -DLLVM_ENABLE_GISEL_COV:BOOL=OFF \
    -DLLVM_ENABLE_HTTPLIB:STRING=OFF \
    -DLLVM_ENABLE_IDE:BOOL=OFF \
    -DLLVM_ENABLE_LIBCXX:BOOL=OFF \
    -DLLVM_ENABLE_LIBEDIT:BOOL=OFF \
    -DLLVM_ENABLE_LIBPFM:BOOL=OFF \
    -DLLVM_ENABLE_LIBXML2:STRING=OFF \
    -DLLVM_ENABLE_LLD:BOOL=OFF \
    -DLLVM_ENABLE_LOCAL_SUBMODULE_VISIBILITY:BOOL=ON \
    -DLLVM_ENABLE_LTO:STRING=ON \
    -DLLVM_ENABLE_MODULES:BOOL=OFF \
    -DLLVM_ENABLE_MODULE_DEBUGGING:BOOL=OFF \
    -DLLVM_ENABLE_NEW_PASS_MANAGER:BOOL=TRUE \
    -DLLVM_ENABLE_OCAMLDOC:BOOL=OFF \
    -DLLVM_ENABLE_PEDANTIC:BOOL=OFF \
    -DLLVM_ENABLE_PER_TARGET_RUNTIME_DIR:BOOL=ON \
    -DLLVM_ENABLE_PIC:BOOL=ON \
    -DLLVM_ENABLE_PLUGINS:BOOL=OFF \
    -DLLVM_ENABLE_PROJECTS:STRING= \
    -DLLVM_ENABLE_RTTI:BOOL=OFF \
    -DLLVM_ENABLE_RUNTIMES:STRING= \
    -DLLVM_ENABLE_SPHINX:BOOL=OFF \
    -DLLVM_ENABLE_STRICT_FIXED_SIZE_VECTORS:BOOL=OFF \
    -DLLVM_ENABLE_TERMINFO:BOOL=OFF \
    -DLLVM_ENABLE_THREADS:BOOL=ON \
    -DLLVM_ENABLE_UNWIND_TABLES:BOOL=OFF \
    -DLLVM_ENABLE_WARNINGS:BOOL=ON \
    -DLLVM_ENABLE_WERROR:BOOL=OFF \
    -DLLVM_ENABLE_Z3_SOLVER:BOOL=OFF \
    -DLLVM_ENABLE_ZLIB:STRING=OFF \
    -DLLVM_ENABLE_ZSTD:STRING=OFF \
    -DLLVM_EXPERIMENTAL_TARGETS_TO_BUILD:STRING= \
    -DLLVM_EXPORT_SYMBOLS_FOR_PLUGINS:BOOL=OFF \
    -DLLVM_EXTERNALIZE_DEBUGINFO:BOOL=OFF \
    -DLLVM_EXTERNAL_BOLT_SOURCE_DIR:PATH= \
    -DLLVM_EXTERNAL_CLANG_SOURCE_DIR:PATH= \
    -DLLVM_EXTERNAL_COMPILER_RT_SOURCE_DIR:PATH= \
    -DLLVM_EXTERNAL_CROSS_PROJECT_TESTS_SOURCE_DIR:PATH= \
    -DLLVM_EXTERNAL_DRAGONEGG_SOURCE_DIR:PATH= \
    -DLLVM_EXTERNAL_FLANG_SOURCE_DIR:PATH= \
    -DLLVM_EXTERNAL_LIBCXXABI_SOURCE_DIR:PATH= \
    -DLLVM_EXTERNAL_LIBCXX_SOURCE_DIR:PATH= \
    -DLLVM_EXTERNAL_LIBC_SOURCE_DIR:PATH= \
    -DLLVM_EXTERNAL_LIBUNWIND_SOURCE_DIR:PATH= \
    -DLLVM_EXTERNAL_LIT:STRING= \
    -DLLVM_EXTERNAL_LLDB_SOURCE_DIR:PATH= \
    -DLLVM_EXTERNAL_LLD_SOURCE_DIR:PATH= \
    -DLLVM_EXTERNAL_MLIR_SOURCE_DIR:PATH= \
    -DLLVM_EXTERNAL_OPENMP_SOURCE_DIR:PATH= \
    -DLLVM_EXTERNAL_POLLY_SOURCE_DIR:PATH= \
    -DLLVM_EXTERNAL_PSTL_SOURCE_DIR:PATH= \
    -DLLVM_EXTRACT_SYMBOLS_FLAGS:STRING= \
    -DLLVM_FILECHECK_EXE:PATH=/bin/FileCheck \
    -DLLVM_FORCE_ENABLE_STATS:BOOL=OFF \
    -DLLVM_FORCE_USE_OLD_TOOLCHAIN:BOOL=OFF \
    -DLLVM_INCLUDE_BENCHMARKS:BOOL=OFF \
    -DLLVM_INCLUDE_DOCS:BOOL=OFF \
    -DLLVM_INCLUDE_EXAMPLES:BOOL=OFF \
    -DLLVM_INCLUDE_GO_TESTS:BOOL=OFF \
    -DLLVM_INCLUDE_RUNTIMES:BOOL=ON \
    -DLLVM_INCLUDE_TESTS:BOOL=OFF \
    -DLLVM_INCLUDE_TOOLS:BOOL=OFF \
    -DLLVM_INCLUDE_UTILS:BOOL=OFF \
    -DLLVM_INSTALL_BINUTILS_SYMLINKS:BOOL=OFF \
    -DLLVM_INSTALL_CCTOOLS_SYMLINKS:BOOL=OFF \
    -DLLVM_INSTALL_DOXYGEN_HTML_DIR:STRING=share/doc/LLVM/llvm/doxygen-html \
    -DLLVM_INSTALL_MODULEMAPS:BOOL=OFF \
    -DLLVM_INSTALL_OCAMLDOC_HTML_DIR:STRING=share/doc/LLVM/llvm/ocaml-html \
    -DLLVM_INSTALL_PACKAGE_DIR:STRING=lib/cmake/llvm \
    -DLLVM_INSTALL_TOOLCHAIN_ONLY:BOOL=OFF \
    -DLLVM_INSTALL_UTILS:BOOL=OFF \
    -DLLVM_INTEGRATED_CRT_ALLOC:PATH= \
    -DLLVM_LIBDIR_SUFFIX:STRING= \
    -DLLVM_LIB_FUZZING_ENGINE:PATH= \
    -DLLVM_LINK_LLVM_DYLIB:BOOL=OFF \
    -DLLVM_LIT_ARGS:STRING=-sv \
    -DLLVM_LOCAL_RPATH:FILEPATH= \
    -DLLVM_OMIT_DAGISEL_COMMENTS:BOOL=OFF \
    -DLLVM_OPTIMIZED_TABLEGEN:BOOL=OFF \
    -DLLVM_OPTIMIZE_SANITIZED_BUILDS:BOOL=ON \
    -DLLVM_PARALLEL_COMPILE_JOBS:STRING= \
    -DLLVM_PARALLEL_LINK_JOBS:STRING= \
    -DLLVM_PROFDATA_FILE:FILEPATH= \
    -DLLVM_SOURCE_PREFIX:STRING= \
    -DLLVM_STATIC_LINK_CXX_STDLIB:BOOL=OFF \
    -DLLVM_TABLEGEN:STRING=llvm-tblgen \
    -DLLVM_TARGETS_TO_BUILD:STRING=all \
    -DLLVM_TARGET_ARCH:STRING=host \
    -DLLVM_TEMPORARILY_ALLOW_OLD_TOOLCHAIN:BOOL=OFF \
    -DLLVM_TOOL_BOLT_BUILD:BOOL=OFF \
    -DLLVM_TOOL_CLANG_BUILD:BOOL=OFF \
    -DLLVM_TOOL_COMPILER_RT_BUILD:BOOL=OFF \
    -DLLVM_TOOL_CROSS_PROJECT_TESTS_BUILD:BOOL=OFF \
    -DLLVM_TOOL_DRAGONEGG_BUILD:BOOL=OFF \
    -DLLVM_TOOL_FLANG_BUILD:BOOL=OFF \
    -DLLVM_TOOL_LIBCXXABI_BUILD:BOOL=OFF \
    -DLLVM_TOOL_LIBCXX_BUILD:BOOL=OFF \
    -DLLVM_TOOL_LIBC_BUILD:BOOL=OFF \
    -DLLVM_TOOL_LIBUNWIND_BUILD:BOOL=OFF \
    -DLLVM_TOOL_LLDB_BUILD:BOOL=OFF \
    -DLLVM_TOOL_LLD_BUILD:BOOL=OFF \
    -DLLVM_TOOL_MLIR_BUILD:BOOL=OFF \
    -DLLVM_TOOL_OPENMP_BUILD:BOOL=OFF \
    -DLLVM_TOOL_POLLY_BUILD:BOOL=OFF \
    -DLLVM_TOOL_PSTL_BUILD:BOOL=OFF \
    -DLLVM_UNREACHABLE_OPTIMIZE:BOOL=ON \
    -DLLVM_USE_FOLDERS:BOOL=ON \
    -DLLVM_USE_INTEL_JITEVENTS:BOOL=OFF \
    -DLLVM_USE_OPROFILE:BOOL=OFF \
    -DLLVM_USE_PERF:BOOL=OFF \
    -DLLVM_USE_RELATIVE_PATHS_IN_DEBUG_INFO:BOOL=OFF \
    -DLLVM_USE_RELATIVE_PATHS_IN_FILES:BOOL=OFF \
    -DLLVM_USE_SANITIZER:STRING= \
    -DLLVM_USE_SPLIT_DWARF:BOOL=OFF \
    -DLLVM_USE_STATIC_ZSTD:BOOL=FALSE \
    -DLLVM_VERSION_PRINTER_SHOW_HOST_TARGET_INFO:BOOL=ON \
    -DLLVM_WINDOWS_PREFER_FORWARD_SLASH:BOOL=OFF \
    -DLLVM_Z3_INSTALL_DIR:STRING= \
    -DPY_PYGMENTS_FOUND:BOOL=OFF \
    -DPY_PYGMENTS_LEXERS_C_CPP_FOUND:BOOL=OFF \
    -DPY_YAML_FOUND:BOOL=OFF \
    -DTENSORFLOW_AOT_PATH:PATH= \
    -DTENSORFLOW_C_LIB_PATH:PATH= \
    -GNinja >> benchmark.log 2>&1 || \
        aberr "Failed to configure LLVM: $?."

abinfo "(6/6) Benchmarking Buildbot: Building LLVM ..."
time ninja 2>> benchmark.log || \
    aberr "Failed to build LLVM: $?."