include(CheckCXXCompilerFlag)
include(CMakePushCheckState)

# Calls `message(VERBOSE msg)` if and only if VERBOSE is available (since CMake 3.15).
# Call CMake with --loglevel=VERBOSE to view those messages.
function(message_verbose msg)
  if(NOT ${CMAKE_VERSION} VERSION_LESS "3.15")
    message(VERBOSE ${msg})
  endif()
endfunction()

function(use_fastest_linker)
  if(NOT CMAKE_CURRENT_SOURCE_DIR STREQUAL CMAKE_SOURCE_DIR)
    message(WARNING "use_fastest_linker() disabled, as it is not called at the project top level")
    return()
  endif()

  cmake_push_check_state()
  set(CMAKE_REQUIRED_LIBRARIES "-fuse-ld=lld")
  check_cxx_compiler_flag("" HAS_FLAG_FUSE_LD_LLD)
  cmake_pop_check_state()

  cmake_push_check_state()
  set(CMAKE_REQUIRED_LIBRARIES "-fuse-ld=gold")
  check_cxx_compiler_flag("" HAS_FLAG_FUSE_LD_GOLD)
  cmake_pop_check_state()

  if(HAS_FLAG_FUSE_LD_LLD)
    link_libraries(-fuse-ld=lld)
    message_verbose("Using lld linker for faster linking")
  elseif(HAS_FLAG_FUSE_LD_GOLD)
    link_libraries(-fuse-ld=gold)
    message_verbose("Using gold linker for faster linking")
  else()
    message_verbose("Using default linker")
  endif()
endfunction()

option(USE_FASTER_LINKER "Use the lld or gold linker instead of the default for faster linking" TRUE)
if(USE_FASTER_LINKER)
  use_fastest_linker()
endif()
