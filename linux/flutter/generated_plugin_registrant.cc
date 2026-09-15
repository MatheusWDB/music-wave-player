//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <ffmpeg_kit_flutter_new/f_fmpeg_kit_flutter_plugin.h>
#include <file_saver/file_saver_plugin.h>
#include <mpv_audio_kit/mpv_audio_kit_plugin.h>
#include <url_launcher_linux/url_launcher_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) ffmpeg_kit_flutter_new_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "FFmpegKitFlutterPlugin");
  f_fmpeg_kit_flutter_plugin_register_with_registrar(ffmpeg_kit_flutter_new_registrar);
  g_autoptr(FlPluginRegistrar) file_saver_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "FileSaverPlugin");
  file_saver_plugin_register_with_registrar(file_saver_registrar);
  g_autoptr(FlPluginRegistrar) mpv_audio_kit_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "MpvAudioKitPlugin");
  mpv_audio_kit_plugin_register_with_registrar(mpv_audio_kit_registrar);
  g_autoptr(FlPluginRegistrar) url_launcher_linux_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "UrlLauncherPlugin");
  url_launcher_plugin_register_with_registrar(url_launcher_linux_registrar);
}
