package io.github.txmmytwostraps.delta;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.Build;

/** Receives the alarm and shows the reminder; tapping it opens Delta. */
public class ReminderReceiver extends BroadcastReceiver {
    private static final String CHANNEL = "delta_reminders";

    @Override
    public void onReceive(Context context, Intent intent) {
        int id = intent.getIntExtra("id", 1);
        String title = intent.getStringExtra("title");
        String text = intent.getStringExtra("text");
        NotificationManager manager = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(new NotificationChannel(CHANNEL, "Reminders", NotificationManager.IMPORTANCE_DEFAULT));
        }
        Intent launch = context.getPackageManager().getLaunchIntentForPackage(context.getPackageName());
        int flags = PendingIntent.FLAG_UPDATE_CURRENT;
        if (Build.VERSION.SDK_INT >= 23) {
            flags |= PendingIntent.FLAG_IMMUTABLE;
        }
        PendingIntent open = launch == null ? null : PendingIntent.getActivity(context, 0, launch, flags);
        Notification.Builder builder = Build.VERSION.SDK_INT >= 26 ? new Notification.Builder(context, CHANNEL) : new Notification.Builder(context);
        builder.setContentTitle(title == null ? "Delta" : title)
                .setContentText(text == null ? "" : text)
                .setSmallIcon(context.getApplicationInfo().icon)
                .setAutoCancel(true);
        if (open != null) {
            builder.setContentIntent(open);
        }
        manager.notify(id, builder.build());
    }
}
