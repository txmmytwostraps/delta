@tool
extends EditorPlugin
## Puts the reminders plugin into the Android build: its jar, the receiver
## that shows the notification, the permission, and the line that tells the
## Godot Android library which class to load.

var _plugin: AndroidExportPlugin


func _enter_tree() -> void:
	_plugin = AndroidExportPlugin.new()
	add_export_plugin(_plugin)


func _exit_tree() -> void:
	remove_export_plugin(_plugin)
	_plugin = null


class AndroidExportPlugin extends EditorExportPlugin:
	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_name() -> String:
		return "DeltaNotify"

	func _get_android_libraries(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		return PackedStringArray(["delta_notify/bin/delta_notify.jar"])

	func _get_android_manifest_element_contents(_platform: EditorExportPlatform, _debug: bool) -> String:
		return "<uses-permission android:name=\"android.permission.POST_NOTIFICATIONS\" />\n"

	func _get_android_manifest_application_element_contents(_platform: EditorExportPlatform, _debug: bool) -> String:
		return "<meta-data android:name=\"org.godotengine.plugin.v2.DeltaNotify\" android:value=\"io.github.txmmytwostraps.delta.DeltaNotify\" />\n" \
			+ "<receiver android:name=\"io.github.txmmytwostraps.delta.ReminderReceiver\" android:exported=\"false\" />\n"
