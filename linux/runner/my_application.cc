#include "my_application.h"

#include <flutter_linux/flutter_linux.h>

#include "flutter/generated_plugin_registrant.h"

// Below this the app switches to its phone layout, which still works.
static constexpr int kMinWidth = 400;
static constexpr int kMinHeight = 600;

struct _MyApplication {
  GtkApplication parent_instance;
  GtkWindow* window;
  FlMethodChannel* open_files_channel;
  FlMethodChannel* window_channel;
  // Books the desktop asked Yomu to open (file manager "Open With", a
  // double-click, `yomu book.epub`) before Dart started listening.
  GPtrArray* pending_paths;
  gboolean flutter_is_listening;
  // Last size of the window when it wasn't maximized or full screen, saved
  // on quit so the next launch opens the same way.
  int width;
  int height;
  gboolean maximized;
  gboolean fullscreen;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

static gchar* window_state_path() {
  return g_build_filename(g_get_user_config_dir(), APPLICATION_ID,
                          "window.ini", nullptr);
}

static void load_window_state(MyApplication* self) {
  self->width = 1280;
  self->height = 820;
  self->maximized = FALSE;
  g_autofree gchar* path = window_state_path();
  g_autoptr(GKeyFile) file = g_key_file_new();
  if (!g_key_file_load_from_file(file, path, G_KEY_FILE_NONE, nullptr)) return;
  int width = g_key_file_get_integer(file, "window", "width", nullptr);
  int height = g_key_file_get_integer(file, "window", "height", nullptr);
  if (width >= kMinWidth && height >= kMinHeight) {
    self->width = width;
    self->height = height;
  }
  self->maximized = g_key_file_get_boolean(file, "window", "maximized", nullptr);
}

static void save_window_state(MyApplication* self) {
  g_autofree gchar* path = window_state_path();
  g_autofree gchar* dir = g_path_get_dirname(path);
  g_mkdir_with_parents(dir, 0700);
  g_autoptr(GKeyFile) file = g_key_file_new();
  g_key_file_set_integer(file, "window", "width", self->width);
  g_key_file_set_integer(file, "window", "height", self->height);
  g_key_file_set_boolean(file, "window", "maximized", self->maximized);
  g_key_file_save_to_file(file, path, nullptr);
}

static gboolean window_configure_cb(GtkWidget* widget, GdkEvent* event,
                                    MyApplication* self) {
  if (!self->maximized && !self->fullscreen) {
    gtk_window_get_size(GTK_WINDOW(widget), &self->width, &self->height);
  }
  return FALSE;
}

static gboolean window_state_cb(GtkWidget* widget, GdkEventWindowState* event,
                                MyApplication* self) {
  self->maximized =
      (event->new_window_state & GDK_WINDOW_STATE_MAXIMIZED) != 0;
  self->fullscreen =
      (event->new_window_state & GDK_WINDOW_STATE_FULLSCREEN) != 0;
  return FALSE;
}

static FlValue* take_pending_paths(MyApplication* self) {
  FlValue* list = fl_value_new_list();
  for (guint i = 0; i < self->pending_paths->len; i++) {
    fl_value_append_take(
        list, fl_value_new_string(static_cast<const gchar*>(
                  g_ptr_array_index(self->pending_paths, i))));
  }
  g_ptr_array_set_size(self->pending_paths, 0);
  return list;
}

// Flutter calls takePending once it listens, and gets anything that arrived
// while the app was starting. Mirrors macos/Runner/AppDelegate.swift.
static void open_files_method_cb(FlMethodChannel* channel,
                                 FlMethodCall* method_call,
                                 gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  g_autoptr(FlMethodResponse) response = nullptr;
  if (g_strcmp0(fl_method_call_get_name(method_call), "takePending") == 0) {
    self->flutter_is_listening = TRUE;
    g_autoptr(FlValue) list = take_pending_paths(self);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(list));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }
  fl_method_call_respond(method_call, response, nullptr);
}

static void window_method_cb(FlMethodChannel* channel,
                             FlMethodCall* method_call, gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  g_autoptr(FlMethodResponse) response = nullptr;
  if (g_strcmp0(fl_method_call_get_name(method_call), "toggleFullScreen") ==
      0) {
    if (self->fullscreen) {
      gtk_window_unfullscreen(self->window);
    } else {
      gtk_window_fullscreen(self->window);
    }
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (g_strcmp0(fl_method_call_get_name(method_call), "close") == 0) {
    // Closes like the title bar's button does, so the window size is saved.
    gtk_window_close(self->window);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }
  fl_method_call_respond(method_call, response, nullptr);
}

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

static void create_window(MyApplication* self) {
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(self)));
  self->window = window;
  gtk_window_set_title(window, "Yomu");
  gtk_window_set_icon_name(window, APPLICATION_ID);

  load_window_state(self);
  GdkGeometry hints = {};
  hints.min_width = kMinWidth;
  hints.min_height = kMinHeight;
  gtk_window_set_geometry_hints(window, nullptr, &hints, GDK_HINT_MIN_SIZE);
  gtk_window_set_default_size(window, self->width, self->height);
  if (self->maximized) gtk_window_maximize(window);
  g_signal_connect(window, "configure-event", G_CALLBACK(window_configure_cb),
                   self);
  g_signal_connect(window, "window-state-event", G_CALLBACK(window_state_cb),
                   self);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  FlView* view = fl_view_new(project);
  // Yomu's background (YomuConstants.background), so the window doesn't
  // flash black or white while the first frame renders.
  GdkRGBA background_color;
  gdk_rgba_parse(&background_color, "#0A0B0E");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  FlEngine* engine = fl_view_get_engine(view);
  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  FlBinaryMessenger* messenger = fl_engine_get_binary_messenger(engine);
  self->open_files_channel = fl_method_channel_new(
      messenger, "yomu/open_files", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      self->open_files_channel, open_files_method_cb, self, nullptr);
  self->window_channel = fl_method_channel_new(messenger, "yomu/window",
                                               FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(self->window_channel,
                                            window_method_cb, self, nullptr);

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::activate. Yomu is a single-instance app: opening
// it again brings the open window forward instead of starting a second copy
// on the same library.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  if (self->window == nullptr) {
    create_window(self);
  } else {
    gtk_window_present(self->window);
  }
}

// Implements GApplication::open: books opened with Yomu from the file
// manager or the command line, including while it's already running.
static void my_application_open(GApplication* application, GFile** files,
                                gint n_files, const gchar* hint) {
  MyApplication* self = MY_APPLICATION(application);
  my_application_activate(application);

  g_autoptr(FlValue) list = fl_value_new_list();
  for (gint i = 0; i < n_files; i++) {
    gchar* path = g_file_get_path(files[i]);
    if (path == nullptr) continue;
    fl_value_append_take(list, fl_value_new_string(path));
    g_ptr_array_add(self->pending_paths, path);
  }

  if (self->flutter_is_listening) {
    g_ptr_array_set_size(self->pending_paths, 0);
    fl_method_channel_invoke_method(self->open_files_channel, "open", list,
                                    nullptr, nullptr, nullptr);
  }
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  if (self->window != nullptr) save_window_state(self);
  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_object(&self->open_files_channel);
  g_clear_object(&self->window_channel);
  g_clear_pointer(&self->pending_paths, g_ptr_array_unref);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->open = my_application_open;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {
  self->pending_paths = g_ptr_array_new_with_free_func(g_free);
}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_HANDLES_OPEN, nullptr));
}
