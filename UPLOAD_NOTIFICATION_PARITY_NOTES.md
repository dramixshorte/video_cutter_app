# Upload Notification Parity & Android 15 Compliance

## أهداف
- تطابق كامل مع لوحة الرفع البنفسجية داخل التطبيق (ألوان، أيقونات، شريطي تقدم، أزرار التحكم).
- دعم كامل للأجهزة (Xiaomi/Redmi, Samsung) و Android 13 → 15.
- تقليل الأذونات لتفادي الرفض في Android 14/15 وتجنب القيود الخاصة بـ MIUI.

## العناصر المضمنة الآن
| عنصر | الحالة | ملاحظات |
|------|--------|---------|
| شريط تقدم إجمالي | مدمج | progress_overall + percent_overall |
| شريط تقدم الحلقة | مدمج | progress_episode + percent_episode |
| الحالة (رفع/متوقف/مكتمل/خطأ) | مدمج | أيقونة ديناميكية ic_upload / ic_play / ic_done / ic_error |
| عنوان ديناميكي | مدمج | يعرض النسبة + حالة التوقف |
| رسالة سفلية | مدمج | message (آخر حدث) |
| رقم الحلقة الحالية/الإجمالي | مدمج | label_episode (الحلقة X/Y) |
| زر إيقاف/استئناف | مدمج | ACTION_PAUSE / ACTION_RESUME |
| زر إلغاء | مدمج | ACTION_CANCEL (ينهي الخدمة) |
| زر تنظيف | مدمج | ACTION_CLEAN يستدعي cleanLocalEpisodes() في Dart |
| زر تصغير/استرجاع | مدمج | ACTION_TOGGLE_COLLAPSE يبدل full ↔ collapsed |
| زر إخفاء | متاح كـ ACTION_HIDE (غير معروض كأيقونة حالياً) |
| رد اللمس إلى Dart | مدمج | عبر MethodChannel native* callbacks |

## القناة & MethodChannel
- channel: `upload_foreground_channel`
- استدعاء من Dart: `updateForegroundFull` يحمل الحقول:
```
{
  title, message,
  overallProgress (0..100 or -1 indeterminate),
  episodeProgress (0..100 or -1),
  episodeIndex, totalEpisodes,
  status: running|paused|completed|error,
  paused: bool,
  hasLocalEpisodes: bool,
  collapsed: bool
}
```
- استدعاءات راجعة من الجانب الأصلي:
  - nativePause / nativeResume / nativeCancel / nativeClean / nativeToggle(collapsed) / nativeHide

## حالات الأيقونة
| status | paused | الأيقونة |
|--------|--------|----------|
| completed | _ | ic_done_white |
| error | _ | ic_error_white |
| running | false | ic_upload_white |
| running | true | ic_play_white |
| paused | * | ic_play_white |

## اعتبارات MIUI (Xiaomi/Redmi)
1. التأكد من عدم استخدام أنواع خدمة أمامية غير ضرورية (mediaPlayback, specialUse) لتقليل حظر MIUI.
2. إعلام المستخدم (داخل الإعدادات) بمنح: السماح بالتشغيل في الخلفية + تعطيل قيود البطارية للتطبيق.
3. في MIUI 13+: قد يحتاج المستخدم تفعيل "عرض الإشعارات العائمة" للإشعار الكامل.

## اعتبارات Samsung
- عادةً لا توجد قيود إضافية بعد Android 13 عند استخدام نوع خدمة أمامية محدود dataSync.
- يمكن توصية المستخدم بعدم تفعيل وضع التوفير الفائق للطاقة أثناء رفع طويل.

## Android 15 (API 35) ملاحظات استباقية
- حصر foregroundServiceType إلى dataSync فقط (تم في AndroidManifest.xml).
- لا نطلب أذونات وسائط غير مستخدمة (أزلنا READ/WRITE_EXTERNAL/MANAGE_EXTERNAL_STORAGE).
- الإشعار منخفض الأهمية (IMPORTANCE_LOW) فلا يسبب تحذيرات "excessive".

## نقاط تحسين مستقبلية
- إضافة زر ظاهر لإخفاء الإشعار (ACTION_HIDE) إذا رغبت UX.
- دعم قناة إخطار ثانوية للحالات النهائية (نجاح/فشل) منفصلة عن الإشعار المستمر.
- إضافة محتوى غني (صور مصغرة للحلقة الحالية) مع `setStyle` مخصص إن احتجنا.
- دمج WorkManager fallback لو استأنف الجهاز بعد إعادة تشغيل مفاجئ.

## تدفق الإيقاف / الاستئناف
1. المستخدم يلمس زر الإيقاف المؤقت ⇒ ACTION_PAUSE ⇒ الخدمة تحدّث lastPaused وترسل nativePause ⇒ Dart يستدعي pauseUpload().
2. Dart يبث حالة Paused في الستريم ⇒ updateForegroundFull (status=paused, paused=true) ⇒ الأيقونة تتغير إلى play.
3. المستخدم يلمس زر الاستئناف ⇒ ACTION_RESUME → nativeResume → Dart resumeUpload() → بث running.

## تنظيف الملفات
- ACTION_CLEAN يستدعي cleanLocalEpisodes()؛ إذا أصبحت القائمة فارغة يمكن إخفاء شريط الحلقة (نحتاج تحديث لاحق لإخفاء container لو totalEpisodes=0).

## الطي/التوسيع
- ACTION_TOGGLE_COLLAPSE يغيّر lastCollapsed ويعيد بناء RemoteViews.
- Dart يحتفظ بحقل _collapsed ويعيد إرساله في كل updateForegroundFull ليحافظ على التزامن بعد أي تحديث جديد.

## fallback
- ما زلنا ننشئ إشعار Flutter قياسي (plugin) لضمان ظهور تقدّم لو فشل جزء الخدمة الأصلية؛ يمكن لاحقاً إلغاءه عند استقرار السلوك.

---
آخر تحديث: (تحديث تلقائي أولي) – عدل الملف لمزيد التفاصيل إذا ظهرت احتياجات جديدة.
