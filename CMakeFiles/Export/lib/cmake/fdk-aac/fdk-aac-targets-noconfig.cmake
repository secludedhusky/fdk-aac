#----------------------------------------------------------------
# Generated CMake target import file.
#----------------------------------------------------------------

# Commands may need to know the format version.
set(CMAKE_IMPORT_FILE_VERSION 1)

# Import target "FDK-AAC::fdk-aac" for configuration ""
set_property(TARGET FDK-AAC::fdk-aac APPEND PROPERTY IMPORTED_CONFIGURATIONS NOCONFIG)
set_target_properties(FDK-AAC::fdk-aac PROPERTIES
  IMPORTED_LOCATION_NOCONFIG "${_IMPORT_PREFIX}/lib/libfdk-aac.so.2.0.3"
  IMPORTED_SONAME_NOCONFIG "libfdk-aac.so.2"
  )

list(APPEND _IMPORT_CHECK_TARGETS FDK-AAC::fdk-aac )
list(APPEND _IMPORT_CHECK_FILES_FOR_FDK-AAC::fdk-aac "${_IMPORT_PREFIX}/lib/libfdk-aac.so.2.0.3" )

# Commands beyond this point should not need to know the version.
set(CMAKE_IMPORT_FILE_VERSION)
