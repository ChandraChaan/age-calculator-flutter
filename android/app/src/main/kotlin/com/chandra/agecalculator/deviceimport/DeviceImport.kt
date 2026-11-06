package com.chandra.agecalculator.deviceimport

import android.Manifest
import android.app.Activity
import android.content.ContentUris
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.CalendarContract
import android.provider.ContactsContract
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Reads birthdays from contacts and upcoming events from calendars so the
 * user can import them. Read-only: nothing is ever written to the user's
 * contacts or calendars, and nothing leaves the device.
 */
class DeviceImport(private val activity: Activity, messenger: BinaryMessenger) :
    MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "com.chandra.agecalculator/device_import"
        const val REQUEST_CODE = 4207
        private const val MAX_DAYS = 366
    }

    private val channel = MethodChannel(messenger, CHANNEL)
    private val main = Handler(Looper.getMainLooper())
    private var pendingPermission: Pair<String, MethodChannel.Result>? = null

    init {
        channel.setMethodCallHandler(this)
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        pendingPermission?.second?.success("denied")
        pendingPermission = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "permissionStatus" -> {
                val permission = permissionFor(call) ?: return badKind(result)
                result.success(if (isGranted(permission)) "granted" else "denied")
            }
            "requestPermission" -> {
                val permission = permissionFor(call) ?: return badKind(result)
                requestPermission(permission, result)
            }
            "openAppSettings" -> {
                val intent = Intent(
                    Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                    Uri.fromParts("package", activity.packageName, null),
                ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                activity.startActivity(intent)
                result.success(true)
            }
            "contactEvents" -> {
                if (!isGranted(Manifest.permission.READ_CONTACTS)) {
                    return result.error("no_permission", "READ_CONTACTS not granted", null)
                }
                inBackground(result) { contactEvents() }
            }
            "calendarEvents" -> {
                if (!isGranted(Manifest.permission.READ_CALENDAR)) {
                    return result.error("no_permission", "READ_CALENDAR not granted", null)
                }
                val days = (call.argument<Int>("days") ?: 90).coerceIn(1, MAX_DAYS)
                inBackground(result) { calendarEvents(days) }
            }
            else -> result.notImplemented()
        }
    }

    /** Called from the activity's onRequestPermissionsResult. */
    fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray): Boolean {
        if (requestCode != REQUEST_CODE) return false
        val (permission, result) = pendingPermission ?: return true
        pendingPermission = null
        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        result.success(
            when {
                granted -> "granted"
                // After a denial Android stops asking once the user chose
                // "Don't allow" twice; only Settings can grant it then.
                Build.VERSION.SDK_INT >= 23 &&
                    !activity.shouldShowRequestPermissionRationale(permission) -> "blocked"
                else -> "denied"
            },
        )
        return true
    }

    private fun permissionFor(call: MethodCall): String? =
        when (call.argument<String>("kind")) {
            "contacts" -> Manifest.permission.READ_CONTACTS
            "calendar" -> Manifest.permission.READ_CALENDAR
            else -> null
        }

    private fun badKind(result: MethodChannel.Result) =
        result.error("bad_args", "kind must be contacts or calendar", null)

    private fun isGranted(permission: String): Boolean =
        Build.VERSION.SDK_INT < 23 ||
            activity.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED

    private fun requestPermission(permission: String, result: MethodChannel.Result) {
        if (isGranted(permission)) return result.success("granted")
        if (pendingPermission != null) {
            return result.error("busy", "a permission request is already open", null)
        }
        pendingPermission = permission to result
        activity.requestPermissions(arrayOf(permission), REQUEST_CODE)
    }

    private fun inBackground(result: MethodChannel.Result, work: () -> Any?) {
        Thread {
            try {
                val value = work()
                main.post { result.success(value) }
            } catch (e: Exception) {
                main.post { result.error("read_failed", e.message, null) }
            }
        }.start()
    }

    private fun contactEvents(): List<Map<String, Any?>> {
        val projection = arrayOf(
            ContactsContract.Data.CONTACT_ID,
            ContactsContract.Data.DISPLAY_NAME,
            ContactsContract.CommonDataKinds.Event.START_DATE,
            ContactsContract.CommonDataKinds.Event.TYPE,
        )
        val selection = "${ContactsContract.Data.MIMETYPE} = ? AND " +
            "${ContactsContract.CommonDataKinds.Event.TYPE} IN (?, ?)"
        val args = arrayOf(
            ContactsContract.CommonDataKinds.Event.CONTENT_ITEM_TYPE,
            ContactsContract.CommonDataKinds.Event.TYPE_BIRTHDAY.toString(),
            ContactsContract.CommonDataKinds.Event.TYPE_ANNIVERSARY.toString(),
        )
        val rows = ArrayList<Map<String, Any?>>()
        activity.contentResolver.query(
            ContactsContract.Data.CONTENT_URI,
            projection,
            selection,
            args,
            "${ContactsContract.Data.DISPLAY_NAME} ASC",
        )?.use { cursor ->
            while (cursor.moveToNext()) {
                val type = cursor.getInt(3)
                rows.add(
                    mapOf(
                        "contactId" to cursor.getLong(0).toString(),
                        "name" to cursor.getString(1),
                        "date" to cursor.getString(2),
                        "type" to if (type ==
                            ContactsContract.CommonDataKinds.Event.TYPE_ANNIVERSARY
                        ) "anniversary" else "birthday",
                    ),
                )
            }
        }
        return rows
    }

    private fun calendarEvents(days: Int): List<Map<String, Any?>> {
        val now = System.currentTimeMillis()
        val end = now + days * 24L * 60 * 60 * 1000
        val uri = CalendarContract.Instances.CONTENT_URI.buildUpon().also {
            ContentUris.appendId(it, now)
            ContentUris.appendId(it, end)
        }.build()
        val projection = arrayOf(
            CalendarContract.Instances.EVENT_ID,
            CalendarContract.Instances.TITLE,
            CalendarContract.Instances.BEGIN,
            CalendarContract.Instances.ALL_DAY,
            CalendarContract.Instances.RRULE,
            CalendarContract.Instances.CALENDAR_DISPLAY_NAME,
        )
        val rows = ArrayList<Map<String, Any?>>()
        activity.contentResolver.query(
            uri,
            projection,
            "${CalendarContract.Instances.VISIBLE} = 1",
            null,
            "${CalendarContract.Instances.BEGIN} ASC",
        )?.use { cursor ->
            while (cursor.moveToNext()) {
                rows.add(
                    mapOf(
                        "eventId" to cursor.getLong(0).toString(),
                        "title" to cursor.getString(1),
                        "begin" to cursor.getLong(2),
                        "allDay" to (cursor.getInt(3) == 1),
                        "rrule" to cursor.getString(4),
                        "calendar" to cursor.getString(5),
                    ),
                )
            }
        }
        return rows
    }
}
