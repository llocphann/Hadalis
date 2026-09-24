cmake_minimum_required(VERSION 3.24)
project(HadalisNiriPreview VERSION 0.2.0 LANGUAGES CXX)

set(CMAKE_AUTOMOC ON)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

find_package(Qt6 6.8 REQUIRED COMPONENTS Core DBus Gui Qml Quick)
find_package(PkgConfig REQUIRED)
pkg_check_modules(PIPEWIRE REQUIRED IMPORTED_TARGET libpipewire-0.3)

add_library(hadalisniripreviewplugin MODULE
  plugin.cpp
  niri_preview_item.cpp
  niri_preview_item.hpp
  capture_backend.cpp
  capture_backend.hpp
)

target_link_libraries(hadalisniripreviewplugin PRIVATE
  Qt6::Core
  Qt6::DBus
  Qt6::Gui
  Qt6::Qml
  Qt6::Quick
  PkgConfig::PIPEWIRE
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
