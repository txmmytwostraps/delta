package io.github.txmmytwostraps.delta;

import android.app.AlarmManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.os.Build;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;

/**
 * Reminders: one alarm that, when it fires, posts a notification through
 * ReminderReceiver. Godot calls schedule() and cancel(); everything else is
 * Android's. The alarm survives the app being closed; it does not survive a
 * reboot, and the app schedules it again the next time it opens.
 */
public class DeltaNotify extends GodotPlugin {
    public DeltaNotify(Godot godot) {
        super(godot);
    }

    @Override
    public String getPluginName() {
        return "DeltaNotify";
    }

    private Context context() {
        return getActivity().getApplicationContext();
    }

    private PendingIntent pending(int id, String title, String text) {
        Intent intent = new Intent(context(), ReminderReceiver.class);
        intent.putExtra("id", id);
        intent.putExtra("title", title);
        intent.putExtra("text", text);
        int flags = PendingIntent.FLAG_UPDATE_CURRENT;
        if (Build.VERSION.SDK_INT >= 23) {
            flags |= PendingIntent.FLAG_IMMUTABLE;
        }
        return PendingIntent.getBroadcast(context(), id, intent, flags);
    }

    /** Posts the notification at the given time (unix seconds), replacing any earlier one with the same id. */
    @UsedByGodot
    public void schedule(int id, int atUnixSeconds, String title, String text) {
        AlarmManager alarms = (AlarmManager) context().getSystemService(Context.ALARM_SERVICE);
        long at = (long) atUnixSeconds * 1000L;
        if (Build.VERSION.SDK_INT >= 23) {
            alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pending(id, title, text));
        } else {
            alarms.set(AlarmManager.RTC_WAKEUP, at, pending(id, title, text));
        }
    }

    @UsedByGodot
    public void cancel(int id) {
        AlarmManager alarms = (AlarmManager) context().getSystemService(Context.ALARM_SERVICE);
        alarms.cancel(pending(id, "", ""));
    }
}
