cmake_minimum_required(VERSION 3.24)
project(HadalisNiriPreview VERSION 0.1.0 LANGUAGES C CXX)

set(CMAKE_AUTOMOC ON)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

find_package(Qt6 6.8 REQUIRED COMPONENTS Core Gui Qml Quick)
find_package(PkgConfig REQUIRED)
pkg_check_modules(WAYLAND REQUIRED IMPORTED_TARGET wayland-client wayland-protocols)
find_program(WAYLAND_SCANNER_EXECUTABLE wayland-scanner REQUIRED)
pkg_get_variable(WAYLAND_PROTOCOLS_DIR wayland-protocols pkgdatadir)

if(NOT WAYLAND_PROTOCOLS_DIR)
  message(FATAL_ERROR "wayland-protocols pkgdatadir is unavailable")
endif()

set(PROTOCOL_DIR "${CMAKE_CURRENT_BINARY_DIR}/protocols")
file(MAKE_DIRECTORY "${PROTOCOL_DIR}")

function(hadalis_wayland_protocol name xml)
  set(header "${PROTOCOL_DIR}/${name}-client-protocol.h")
  set(code "${PROTOCOL_DIR}/${name}-protocol.c")

  add_custom_command(
    OUTPUT "${header}"
    COMMAND "${WAYLAND_SCANNER_EXECUTABLE}" client-header "${xml}" "${header}"
    DEPENDS "${xml}"
    VERBATIM
  )
  add_custom_command(
    OUTPUT "${code}"
    COMMAND "${WAYLAND_SCANNER_EXECUTABLE}" private-code "${xml}" "${code}"
    DEPENDS "${xml}"
    VERBATIM
  )

  set(HADALIS_PROTOCOL_SOURCES
      ${HADALIS_PROTOCOL_SOURCES} "${header}" "${code}"
      PARENT_SCOPE)
endfunction()

hadalis_wayland_protocol(
  ext-foreign-toplevel-list-v1
  "${WAYLAND_PROTOCOLS_DIR}/staging/ext-foreign-toplevel-list/ext-foreign-toplevel-list-v1.xml")
hadalis_wayland_protocol(
  ext-image-capture-source-v1
  "${WAYLAND_PROTOCOLS_DIR}/staging/ext-image-capture-source/ext-image-capture-source-v1.xml")
hadalis_wayland_protocol(
  ext-image-copy-capture-v1
  "${WAYLAND_PROTOCOLS_DIR}/staging/ext-image-copy-capture/ext-image-copy-capture-v1.xml")

add_library(hadalisniripreviewplugin MODULE
  plugin.cpp
  niri_preview_item.cpp
  niri_preview_item.hpp
  capture_backend.cpp
  capture_backend.hpp
  ${HADALIS_PROTOCOL_SOURCES}
)

target_include_directories(hadalisniripreviewplugin PRIVATE "${PROTOCOL_DIR}")
target_compile_definitions(hadalisniripreviewplugin PRIVATE _GNU_SOURCE)
target_link_libraries(hadalisniripreviewplugin PRIVATE
  Qt6::Core
  Qt6::Gui
  Qt6::Qml
  Qt6::Quick
  PkgConfig::WAYLAND
)

set_target_properties(hadalisniripreviewplugin PROPERTIES
  OUTPUT_NAME hadalisniripreviewplugin
)

include(GNUInstallDirs)
set(HADALIS_QML_DIR "${CMAKE_INSTALL_LIBDIR}/qt6/qml/Hadalis/NiriPreview")
install(TARGETS hadalisniripreviewplugin
  LIBRARY DESTINATION "${HADALIS_QML_DIR}")
install(FILES qmldir
  DESTINATION "${HADALIS_QML_DIR}")
