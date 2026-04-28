cmake_minimum_required(VERSION 3.10)

project(callgraphgen LANGUAGES C CXX)

if(NOT DEFINED LLVM_PATH)
  # on ubuntu apt install llvm-19 llvm-19-dev
  find_package(LLVM 19.1 REQUIRED)
  find_package(Clang 19.1 REQUIRED)
else()
  set(LLVM_DIR "${LLVM_PATH}/lib/cmake/llvm")
  set(Clang_DIR "${LLVM_PATH}/lib/cmake/clang")
  find_package(LLVM REQUIRED CONFIG NO_DEFAULT_PATH)
  find_package(Clang REQUIRED CONFIG NO_DEFAULT_PATH)
endif()

message(STATUS "Found LLVM ${LLVM_PACKAGE_VERSION} in ${LLVM_INCLUDE_DIRS}")
message(STATUS "Found Clang in ${CLANG_INCLUDE_DIRS}")
list(APPEND CMAKE_MODULE_PATH "${LLVM_CMAKE_DIR}")
list(APPEND CMAKE_MODULE_PATH "${CLANG_CMAKE_DIR}")
include(AddLLVM)
include(AddClang)
add_clang_executable(callgraphgen main.cpp)
target_include_directories(callgraphgen SYSTEM PRIVATE ${LLVM_INCLUDE_DIRS}
                                                       ${CLANG_INCLUDE_DIRS})
target_link_libraries(
  callgraphgen
  PRIVATE LLVMSupport
          clangAnalysis
          clangAST
          clangBasic
          clangFrontend
          clangSerialization
          clangTooling)
target_compile_definitions(
  callgraphgen
  PRIVATE
    "CLANG_PATH=\"/home/georgefkd/programming/llvm-project/build/bin/clang++\"")
