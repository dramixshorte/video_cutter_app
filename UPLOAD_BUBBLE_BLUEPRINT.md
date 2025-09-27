# blueprint: نسخة مطابقة للبطاقة البنفسجية خارج التطبيق

هدفك: إظهار نفس بطاقة الرفع (التصميم البنفسجي، الأزرار، النسبة، الشريطين) أثناء وجود المستخدم خارج التطبيق.

هناك طريقتان رئيسيتان، مع إيجابيات وسلبيات:

| الطريقة | الشكل | الصلاحيات | التعقيد | ملاحظات |
|---------|-------|-----------|---------|----------|
| 1. إشعار مخصص (Custom Notification + RemoteViews) | داخل شريط الإشعارات فقط، قريب جداً من التصميم | لا شيء إضافي (فقط POST_NOTIFICATIONS Android 13+) | متوسط (Kotlin + قنوات) | آمن ومستقر، لا يطفو فوق التطبيقات، يلتزم قيود النظام |
| 2. فقاعة Overlay (WindowManager / حزمة flutter_overlay_window) | عنصر عائم حر أعلى كل الواجهات | إذن Draw over other apps | أعلى | قد يُزعج المستخدم؛ يحتاج إدارة حياة صارمة |

---
## 1) الإشعار المخصص (RemoteViews)
يسمح بوضع Layout مخصص داخل الإشعار (مع بعض القيود). لا يمكنك تحكم كامل بالـ gradients المعقدة لكن يمكن تقريباً صنع صندوق بزوايا مستديرة وخلفية أرجوانية والنصوص والأزرار.

### الملفات المطلوبة
1. أنشئ مجلد تخطيطات في أندرويد:
```
android/app/src/main/res/layout/notification_upload.xml
```
مثال مبسط:
```xml
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:orientation="vertical"
    android:padding="12dp"
    android:layout_width="match_parent"
    android:layout_height="wrap_content"
    android:background="@drawable/bg_upload_card">

    <LinearLayout
        android:orientation="horizontal"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:gravity="center_vertical">
        <ImageView
            android:id="@+id/icon"
            android:layout_width="20dp"
            android:layout_height="20dp"
            android:src="@mipmap/ic_launcher"/>
        <TextView
            android:id="@+id/title"
            android:layout_marginStart="8dp"
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:textColor="#FFFFFF"
            android:textSize="13sp"
            android:maxLines="2"/>
        <ImageButton
            android:id="@+id/btnPause"
            android:layout_width="32dp"
            android:layout_height="32dp"
            android:background="@android:color/transparent"
            android:src="@drawable/ic_pause_white"/>
        <ImageButton
            android:id="@+id/btnCancel"
            android:layout_width="32dp"
            android:layout_height="32dp"
            android:background="@android:color/transparent"
            android:src="@drawable/ic_close_white"/>
    </LinearLayout>

    <ProgressBar
        style="@android:style/Widget.ProgressBar.Horizontal"
        android:id="@+id/progressOverall"
        android:layout_width="match_parent"
        android:layout_height="8dp"
        android:progress="0"
        android:max="1000"
        android:progressDrawable="@drawable/progress_white"/>

    <ProgressBar
        style="@android:style/Widget.ProgressBar.Horizontal"
        android:id="@+id/progressEpisode"
        android:layout_marginTop="6dp"
        android:layout_width="match_parent"
        android:layout_height="6dp"
        android:max="1000"
        android:progress="0"
        android:progressDrawable="@drawable/progress_episode"/>

    <TextView
        android:id="@+id/footer"
        android:layout_marginTop="6dp"
        android:textColor="#CCFFFFFF"
        android:textSize="11sp"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"/>
</LinearLayout>
```

2. خلفية مخصصة (drawable): `bg_upload_card.xml`:
```xml
<shape xmlns:android="http://schemas.android.com/apk/res/android">
    <gradient android:startColor="#6C63FF" android:endColor="#4A409F" android:angle="315"/>
    <corners android:radius="18dp"/>
</shape>
```

3. شريط تقدم أبيض بسيط (progress_white.xml) إن رغبت.

### كود Kotlin (مثال)
في `android/app/src/main/kotlin/<package>/UploadNotification.kt`:
```kotlin
package YOUR.PACKAGE

import android.app.*
import android.content.*
import android.os.Build
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat

object UploadNotificationNative {
    const val CHANNEL_ID = "upload_progress_channel"
    const val NOTIF_ID = 4440

    fun show(context: Context, data: UploadData) {
        val views = RemoteViews(context.packageName, R.layout.notification_upload).apply {
            setTextViewText(R.id.title, data.title)
            setTextViewText(R.id.footer, data.footer)
            setProgressBar(R.id.progressOverall, 1000, (data.overall*1000).toInt(), false)
            setProgressBar(R.id.progressEpisode, 1000, (data.episode*1000).toInt(), false)
            setOnClickPendingIntent(R.id.btnPause, pendingAction(context, if (data.paused) "resume" else "pause"))
            setOnClickPendingIntent(R.id.btnCancel, pendingAction(context, "cancel"))
        }
        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(data.ongoing)
            .setCustomContentView(views)
            .setCustomBigContentView(views)
            .setStyle(NotificationCompat.DecoratedCustomViewStyle())
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(NOTIF_ID, builder.build())
    }

    private fun pendingAction(ctx: Context, action: String): PendingIntent {
        val i = Intent(ctx, UploadActionReceiver::class.java).apply { putExtra("act", action) }
        return PendingIntent.getBroadcast(ctx, action.hashCode(), i, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }
}
```

و BroadcastReceiver:
```kotlin
class UploadActionReceiver: BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.getStringExtra("act")
        // أرسل عبر MethodChannel إلى Flutter لإيقاف مؤقت / استئناف / إلغاء
        UploadBridge.sendActionToFlutter(action)
    }
}
```

### جسر Flutter <-> Kotlin
- أنشئ MethodChannel في `MainActivity` باسم `upload_native_channel`.
- من Flutter (داخل UploadNotificationService) عند كل تحديث: استدعِ `invokeMethod('updateNotification', {...})` لإرسال القيم.
- في Kotlin: عند استقبال `updateNotification` نادِ `UploadNotificationNative.show`.
- عند ضغط الأزرار في الإشعار: تعود الرسالة بالعكس إلى Flutter لتستدعي `UploadManager.instance.pauseUpload()` الخ.

### نموذج بيانات ترسل من Flutter
```dart
final map = {
  'title': 'رفع – $overall%',
  'footer': 'الحلقة $current/$total (${epPct}%)',
  'overall': overallProgress, // 0..1
  'episode': currentEpisodeProgress, // 0..1
  'paused': isPaused,
  'ongoing': !isPaused,
};
_methodChannel.invokeMethod('updateNotification', map);
```

---
## 2) فقاعة Overlay (تعوم فوق التطبيقات)
### الحزمة المقترحة
`flutter_overlay_window` (أو بديل مثل `floating_bubbles` لكن الأول أكثر تحكماً).

### خطوات سريعة
1. إضافة الحزمة إلى `pubspec.yaml`.
2. طلب الإذن:
```dart
if (!await FlutterOverlayWindow.isPermissionGranted()) {
  await FlutterOverlayWindow.requestPermission();
}
```
3. تعريف entrypoint overlay:
```dart
@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const UploadOverlayApp());
}
```
4. تشغيل overlay عند بدء الرفع:
```dart
FlutterOverlayWindow.showOverlay(
  height: 170,
  width: 250,
  alignment: OverlayAlignment.centerRight,
  enableDrag: true,
);
```
5. إرسال التحديثات: `FlutterOverlayWindow.shareData(data)` ثم في overlay استمع عبر `EventChannel` أو `OverlayWindowManager.events` حسب الحزمة.

### تصميم الواجهة داخل overlay
- أعد بناء نفس البطاقة (نفس Widget الموجود في `global_upload_panel.dart`) لكن مبسطة.
- أزرار: أيقونة pause/play + cancel + minimize (تجعل الحجم صغير دائرة).

### إدارة الحياة
- أغلق overlay عند اكتمال/إلغاء الرفع: `FlutterOverlayWindow.closeOverlay()`.
- تأكد من عدم ترك overlay مفتوح يستهلك موارد.

---
## 3) أيهما تختار الآن؟
- إذا هدفك الأساسي: "يظهر في الأعلى أثناء الخروج" → ابدأ بالإشعار المخصص (أسهل – لا إذن إضافي – مدمج). 
- إذا تريد نسخة طبق الأصل بصرياً خارج شريط الإشعارات كفقاعة حرّة → استخدم overlay (لكن يجب أن تقنع المستخدم بالإذن).

## 4) خطوات تنفيذ الإشعار المخصص بترتيب العمل
1. أضف ملفات `layout/notification_upload.xml` و `drawable/bg_upload_card.xml`.
2. أضف كلاس Kotlin و BroadcastReceiver.
3. عدّل AndroidManifest لتسجيل الـ receiver.
4. أضف MethodChannel في `MainActivity`.
5. عدّل Flutter: في `UploadNotificationService` بدل `_plugin.show` استدعِ channel `updateNotification`.
6. عند الانتهاء أو الإلغاء أرسل `closeNotification` لمسحها.

## 5) تحسين Foreground Service (اختياري)
- عند بدء أول جزء: ارفع الإشعار إلى Foreground (إن استخدمت خدمة منفصلة) لضمان عدم قتل العملية في الخلفية.
- عند الاكتمال: إلغاء foreground مع إبقاء إشعار نهائي قصير.

---
### ملاحظات
- RemoteViews لا تدعم كل خواص Flutter (Animations، Gestures). فقط أحداث نقر للأزرار.
- Overlay يمنحك كامل Flutter UI + سلاسة، لكنه يحتاج إذن خاص وقد يستهلك بطارية.

اختر المسار وسيتم إعداد الكود التفصيلي لك.
