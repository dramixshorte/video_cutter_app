# ملاحظات إشعار الرفع المخصص

هذه الوثيقة تشرح تفاصيل تنفيذ الإشعار المخصص (RemoteViews + Foreground Service) لرفع الحلقات.

## المكونات الرئيسية
1. Foreground Service: `UploadForegroundService` يحافظ على استمرارية العملية في الخلفية ويعرض إشعار تقدم.
2. MethodChannel: اسم القناة `upload_foreground_channel` يُستقبل أوامر:
   - `startForeground(title,text,episodeLine,paused)`
   - `updateForeground(title,text,progress,episodeLine,paused)`
   - `stopForeground()`
3. RemoteViews Layout: ملف `res/layout/notif_upload_compact.xml` يطابق الطابع البنفسجي مع نسبة التقدم.
4. خلفية متدرجة: `res/drawable/notif_upload_bg.xml` (تدرج بنفسجي نصف شفاف إلى بنفسجي كامل).
 5. Layout موسع: `res/layout/notif_upload_expanded.xml` يعرض (عنوان – رسالة – سطر الحلقة – نسبة – أزرار تحكم).
 6. أزرار تفاعلية: (إيقاف مؤقت/استئناف، إلغاء) عبر BroadcastReceiver `UploadActionReceiver`.

## الأيقونات والألوان
- الأيقونة الحالية: `stat_sys_upload` مؤقتة ويمكن لاحقاً استبدالها بأيقونة مت矢矧 custom في `res/drawable/ic_upload_white.xml` أو صورة متجهة SVG محولة إلى VectorDrawable.
- اللون الأساسي (Purple Accent): #6C63FF تم استخدامه في التدرج مع شفافية في البداية (#7F6C63FF).

## السلوك الاحتياطي (Fallback)
إذا فشل أي استدعاء للقناة (MethodChannel) أو حدث استثناء على مستوى الخدمة:
- يستمر النظام في إظهار إشعار Flutter العادي (plugin) لأن `upload_notification_service.dart` يحتوي try/catch حول الاستدعاءات.
- لن يتعطل الرفع لأن المنطق الأساسي للرفع مستقل.

## التوقف والنهاية
- عند اكتمال أو فشل أو إلغاء الرفع يتم استدعاء `stopForeground` تلقائياً، ثم يُعرض إشعار نهائي تلخيصي قصير من خلال Flutter plugin ويُلغى بعد مهلة.

## تطوير لاحق (اختياري)
- إضافة أزرار (إيقاف مؤقت / استئناف / إلغاء) داخل RemoteViews عبر PendingIntents وربطها بـ BroadcastReceiver.
- دعم نمط موسع BigStyle (نسخة ثانية من layout) للشاشات الكبيرة.
- استبدال الأيقونة الافتراضية بأيقونة العلامة التجارية.
 (تم تنفيذ البنود الثلاثة الأولى الآن).

## توافق الإصدارات
- Android 8+ (Oreo): إنشاء قناة إشعار `upload_progress_foreground` إلزامي.
- Android 13+ (Tiramisu): يتطلب إذن POST_NOTIFICATIONS (موجود في Manifest).
- Scoped Storage: لا يعتمد على أذونات خارقة؛ الرفع يعتمد على ملفات ضمن المسار المخصص للتطبيق.

## اختبار سريع
1. ابدأ رفع مسلسل من داخل التطبيق.
2. اسحب شريط الإشعار لأسفل: يظهر الشكل الموسع مع الأزرار.
3. اضغط (إيقاف مؤقت): الزر يتحول إلى (استئناف) ويتجمد شريط التقدم (progress ثابت) والعنوان يتغير.
4. اضغط (استئناف): يعود التقدم للحركة ويعود الزر إلى (إيقاف مؤقت).
5. اضغط (إلغاء): يتوقف الرفع، الخدمة تُغلق، يظهر إشعار ختامي قصير ثم يُزال.
6. بعد اكتمال الرفع: يتم استدعاء stopForeground ويعرض ملخص ثم يختفي.

## تدفق الأوامر (Actions Flow)
زر في الإشعار → BroadcastReceiver → إعادة إرسال Intent إلى الخدمة → تحديث RemoteViews محلياً فوراً → (اختياري) إبلاغ Flutter عبر MethodChannel (حاليًا: Dart يستقبل nativePause/nativeResume/nativeCancel عند إضافتها مستقبلاً في حال تم تفعيل النداء من الجانب الأصلي).

حاليًا يتم تطبيق الإيقاف/الاستئناف/الإلغاء بشكل رئيسي عبر أزرار Flutter الأصلية في الواجهة أو إشعار Flutter plugin، أما النسخة التفاعلية الأصلية تُعد خطوة نحو فصل كامل المنطق لاحقاً.

---
تم إعداد هذا النظام ليكون قابلاً للتطوير لاحقاً نحو تصميم مطابق 100% للبطاقة الداخلية مع أزرار تفاعلية داخل الإشعار.
