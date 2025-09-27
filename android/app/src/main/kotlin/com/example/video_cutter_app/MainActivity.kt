package com.example.video_cutter_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import android.widget.RemoteViews
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel


class MainActivity : FlutterActivity() {
	private val channelName = "upload_foreground_channel"

	override fun onCreate(savedInstanceState: android.os.Bundle?) {
		super.onCreate(savedInstanceState)
		// Channel will also be (re)attached in configureFlutterEngine, but we create a lazy placeholder to avoid missing plugin race early during first frames.
	}

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		val messenger = flutterEngine.dartExecutor.binaryMessenger
		// Single instance
		if (UploadChannelBridge.methodChannel == null) {
			UploadChannelBridge.methodChannel = MethodChannel(messenger, channelName)
		}
		val channel = UploadChannelBridge.methodChannel ?: MethodChannel(messenger, channelName).also { UploadChannelBridge.methodChannel = it }
		channel.setMethodCallHandler { call, result ->
			when (call.method) {
				"startForeground" -> {
					val title: String = call.argument<String>("title") ?: "رفع الحلقات"
					val text: String = call.argument<String>("text") ?: "جارٍ التحضير..."
					startUploadService(title, text)
					result.success(true)
				}
				"updateForeground" -> {
					val title: String = call.argument<String>("title") ?: "رفع الحلقات"
					val text: String = call.argument<String>("text") ?: "جارٍ التحضير..."
					val progress: Int = call.argument<Int>("progress") ?: -1
					UploadForegroundService.updateProgress(this, title, text, progress)
					result.success(true)
				}
				"updateForegroundFull" -> { // New richer update with dual progress + status
					val title: String = call.argument<String>("title") ?: "رفع الحلقات"
					val message: String = call.argument<String>("message") ?: "جارٍ التحضير..."
					val overall: Int = call.argument<Int>("overallProgress") ?: -1
					val episode: Int = call.argument<Int>("episodeProgress") ?: -1
					val episodeIndex: Int = call.argument<Int>("episodeIndex") ?: 0 // 1-based expected
					val totalEpisodes: Int = call.argument<Int>("totalEpisodes") ?: 0
					val status: String = call.argument<String>("status") ?: "running" // running|paused|completed|error
					val paused: Boolean = call.argument<Boolean>("paused") ?: (status == "paused")
					val hasLocal: Boolean = call.argument<Boolean>("hasLocalEpisodes") ?: true
					val collapsed: Boolean = call.argument<Boolean>("collapsed") ?: false
					UploadForegroundService.updateAdvanced(
						this,
						title = title,
						message = message,
						overallProgress = overall,
						episodeProgress = episode,
						episodeIndex = episodeIndex,
						totalEpisodes = totalEpisodes,
						status = status,
						paused = paused,
						hasLocal = hasLocal,
						collapsed = collapsed
					)
					result.success(true)
				}
				"stopForeground" -> {
					stopUploadService()
					result.success(true)
				}
				else -> result.notImplemented()
			}
		}
	}

	private fun startUploadService(title: String, text: String) {
		val intent = Intent(this, UploadForegroundService::class.java).apply {
			action = UploadForegroundService.ACTION_START
			putExtra(UploadForegroundService.EXTRA_TITLE, title)
			putExtra(UploadForegroundService.EXTRA_TEXT, text)
		}
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
			startForegroundService(intent)
		} else {
			startService(intent)
		}
	}

	private fun stopUploadService() {
		val intent = Intent(this, UploadForegroundService::class.java).apply {
			action = UploadForegroundService.ACTION_STOP
		}
		startService(intent)
	}
}

// Foreground service implementation

class UploadForegroundService : Service() {
	companion object {
		const val CHANNEL_ID = "upload_progress_foreground"
		const val ACTION_START = "com.example.video_cutter_app.action.START"
		const val ACTION_STOP = "com.example.video_cutter_app.action.STOP"
		const val ACTION_PAUSE = "com.example.video_cutter_app.action.PAUSE"
		const val ACTION_RESUME = "com.example.video_cutter_app.action.RESUME"
		const val ACTION_CANCEL = "com.example.video_cutter_app.action.CANCEL"
		const val ACTION_CLEAN = "com.example.video_cutter_app.action.CLEAN"
		const val ACTION_TOGGLE_COLLAPSE = "com.example.video_cutter_app.action.TOGGLE_COLLAPSE"
		const val ACTION_HIDE = "com.example.video_cutter_app.action.HIDE"
		const val EXTRA_TITLE = "extra_title"
		const val EXTRA_TEXT = "extra_text"
		const val EXTRA_PROGRESS = "extra_progress"
		private const val NOTIF_ID = 4455
		@Volatile private var lastPaused = false
		@Volatile private var lastProgress = -1
		@Volatile private var lastTitle: String = "رفع الحلقات"
		@Volatile private var lastText: String = "جارٍ التحضير..."
		@Volatile private var lastEpisodeProgress: Int = -1
		@Volatile private var lastEpisodeIndex: Int = 0
		@Volatile private var lastTotalEpisodes: Int = 0
		@Volatile private var lastStatus: String = "running" // running|paused|completed|error
		@Volatile private var lastHasLocal: Boolean = true
		@Volatile private var lastCollapsed: Boolean = false
		@Volatile private var terminated: Boolean = false

		fun updateProgress(context: Context, title: String, text: String, progress: Int) {
			val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
			ensureChannel(nm)
			lastTitle = title
			lastText = text
			lastProgress = progress
			val notif = buildNotification(context)
			nm.notify(NOTIF_ID, notif)
		}

		fun updateAdvanced(
			context: Context,
			title: String,
			message: String,
			overallProgress: Int,
			episodeProgress: Int,
			episodeIndex: Int,
			totalEpisodes: Int,
			status: String,
			paused: Boolean,
			hasLocal: Boolean,
			collapsed: Boolean
		) {
			android.util.Log.d("UploadNotifNative", "updateAdvanced title=$title overall=$overallProgress episode=$episodeProgress status=$status collapsed=$collapsed")
			val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
			ensureChannel(nm)
			lastTitle = title
			lastText = message
			lastProgress = overallProgress
			lastEpisodeProgress = episodeProgress
			lastEpisodeIndex = episodeIndex
			lastTotalEpisodes = totalEpisodes
			lastStatus = status
			lastPaused = paused || status == "paused"
			lastHasLocal = hasLocal
			lastCollapsed = collapsed
			if (!terminated && status == "error") {
				// Auto hide on failure per requirement
				terminated = true
				requestStop(context)
				return
			}
			val notif = buildNotification(context)
			nm.notify(NOTIF_ID, notif)
		}

		private fun baseBuilder(context: Context, title: String, text: String): NotificationCompat.Builder {
			// Use app launcher icon or custom upload icon for brand consistency
			val smallIconId = R.drawable.ic_upload_white.takeIf { try { context.resources.getResourceName(R.drawable.ic_upload_white); true } catch (_: Exception) { false } } ?: R.mipmap.ic_launcher
			return NotificationCompat.Builder(context, CHANNEL_ID)
				.setSmallIcon(smallIconId)
				.setOngoing(true)
				.setPriority(NotificationCompat.PRIORITY_LOW)
				.setOnlyAlertOnce(true)
		}

		private fun buildNotification(context: Context): Notification {
			android.util.Log.d("UploadNotifNative", "buildNotification status=$lastStatus paused=$lastPaused collapsed=$lastCollapsed overall=$lastProgress ep=$lastEpisodeProgress")
			// Decide icon based on status / paused
			val statusIcon = when {
				lastStatus == "completed" -> R.drawable.ic_done_white
				lastStatus == "error" -> R.drawable.ic_error_white
				lastPaused -> R.drawable.ic_play_white
				else -> R.drawable.ic_upload_white
			}
			val contentView = try {
				RemoteViews(context.packageName,
					if (lastCollapsed) R.layout.notif_upload_collapsed else R.layout.notif_upload_full
				)
			} catch (e: Exception) {
				android.util.Log.e("UploadNotifNative", "RemoteViews inflate failed, fallback basic notification: ${e.message}")
				return baseBuilder(context, lastTitle, lastText)
					.setContentTitle(lastTitle)
					.setContentText(lastText.take(60))
					.setOngoing(true)
					.build()
			}
			// In collapsed layout we only show overall progress subset
			contentView.setTextViewText(R.id.title, lastTitle)
			// Common overall progress handling
			if (lastProgress in 0..100) {
				contentView.setProgressBar(R.id.progress_overall, 100, lastProgress, false)
				contentView.setTextViewText(R.id.percent_overall, "${lastProgress}%")
			} else {
				contentView.setProgressBar(R.id.progress_overall, 0, 0, true)
				contentView.setTextViewText(R.id.percent_overall, if (lastCollapsed) "" else "")
			}
			contentView.setImageViewResource(R.id.icon_status, statusIcon)
			if (!lastCollapsed) {
				// Full layout extra bindings
				contentView.setTextViewText(R.id.message, lastText)
				// Overall label
				try { contentView.setTextViewText(R.id.label_overall, "إجمالي الرفع") } catch (_: Exception) {}
				// Episode progress
				val showEpisode = lastTotalEpisodes > 0
				if (showEpisode) {
					if (lastEpisodeProgress in 0..100) {
						contentView.setProgressBar(R.id.progress_episode, 100, lastEpisodeProgress, false)
						contentView.setTextViewText(R.id.percent_episode, "${lastEpisodeProgress}%")
					} else {
						contentView.setProgressBar(R.id.progress_episode, 0, 0, true)
						contentView.setTextViewText(R.id.percent_episode, "")
					}
					contentView.setTextViewText(R.id.label_episode, "الحلقة ${lastEpisodeIndex}/${lastTotalEpisodes}")
				}
				// Buttons / actions only in full layout
				val pauseResumeAction = if (lastPaused) ACTION_RESUME else ACTION_PAUSE
				contentView.setOnClickPendingIntent(R.id.btn_pause_resume, pendingAction(context, pauseResumeAction))
				contentView.setImageViewResource(R.id.btn_pause_resume, if (lastPaused) R.drawable.ic_play_white else R.drawable.ic_pause_white)
				contentView.setOnClickPendingIntent(R.id.btn_clean, pendingAction(context, ACTION_CLEAN))
				contentView.setOnClickPendingIntent(R.id.btn_minimize, pendingAction(context, ACTION_TOGGLE_COLLAPSE))
				contentView.setOnClickPendingIntent(R.id.btn_cancel, pendingAction(context, ACTION_CANCEL))
			}
			// Collapsed has restore button
			if (lastCollapsed) {
				contentView.setOnClickPendingIntent(R.id.btn_restore, pendingAction(context, ACTION_TOGGLE_COLLAPSE))
			}
			val builder = baseBuilder(context, lastTitle, lastText)
			builder.setCustomContentView(contentView)
			// Provide big content view always full layout for expansion
			val big = try { RemoteViews(context.packageName, R.layout.notif_upload_full) } catch (e: Exception) { null }
			big?.apply {
				setTextViewText(R.id.title, lastTitle)
				setTextViewText(R.id.message, lastText)
				if (lastProgress in 0..100) {
					setProgressBar(R.id.progress_overall, 100, lastProgress, false)
					setTextViewText(R.id.percent_overall, "${lastProgress}%")
				} else {
					setProgressBar(R.id.progress_overall, 0, 0, true)
					setTextViewText(R.id.percent_overall, "")
				}
				setImageViewResource(R.id.icon_status, statusIcon)
				if (lastTotalEpisodes > 0) {
					if (lastEpisodeProgress in 0..100) {
						setProgressBar(R.id.progress_episode, 100, lastEpisodeProgress, false)
						setTextViewText(R.id.percent_episode, "${lastEpisodeProgress}%")
					} else {
						setProgressBar(R.id.progress_episode, 0, 0, true)
						setTextViewText(R.id.percent_episode, "")
					}
					setTextViewText(R.id.label_episode, "الحلقة ${lastEpisodeIndex}/${lastTotalEpisodes}")
				}
				val pauseResumeAction2 = if (lastPaused) ACTION_RESUME else ACTION_PAUSE
				setOnClickPendingIntent(R.id.btn_pause_resume, pendingAction(context, pauseResumeAction2))
				setImageViewResource(R.id.btn_pause_resume, if (lastPaused) R.drawable.ic_play_white else R.drawable.ic_pause_white)
				setOnClickPendingIntent(R.id.btn_clean, pendingAction(context, ACTION_CLEAN))
				setOnClickPendingIntent(R.id.btn_minimize, pendingAction(context, ACTION_TOGGLE_COLLAPSE))
				setOnClickPendingIntent(R.id.btn_cancel, pendingAction(context, ACTION_CANCEL))
			}
			if (big != null) builder.setCustomBigContentView(big)
			return builder.build()
		}

		private fun pendingAction(context: Context, action: String): PendingIntent {
			val intent = Intent(context, UploadActionReceiver::class.java).apply { this.action = action }
			val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT else PendingIntent.FLAG_UPDATE_CURRENT
			return PendingIntent.getBroadcast(context, action.hashCode(), intent, flags)
		}

		private fun ensureChannel(nm: NotificationManager) {
			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
				val ch = NotificationChannel(CHANNEL_ID, "رفع الحلقات (Foreground)", NotificationManager.IMPORTANCE_DEFAULT).apply {
					setShowBadge(false)
					lockscreenVisibility = Notification.VISIBILITY_PRIVATE
					setSound(null, null)
					enableVibration(false)
				}
				nm.createNotificationChannel(ch)
			}
		}

		private fun requestStop(context: Context) {
			val intent = Intent(context, UploadForegroundService::class.java).apply { action = ACTION_STOP }
			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) context.startForegroundService(intent) else context.startService(intent)
		}
	}

	override fun onBind(intent: Intent?): IBinder? = null

	override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
		val action = intent?.action
		val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
		ensureChannel(nm)
		return when (action) {
			ACTION_START -> {
				val title = intent.getStringExtra(EXTRA_TITLE) ?: "رفع الحلقات"
				val text = intent.getStringExtra(EXTRA_TEXT) ?: "جارٍ التحضير..."
					lastTitle = title
					lastText = text
					val notif = buildNotification(this)
				startForeground(NOTIF_ID, notif)
				START_STICKY
			}
			ACTION_STOP -> {
				stopForeground(STOP_FOREGROUND_DETACH)
				stopSelf()
				START_NOT_STICKY
			}
			ACTION_PAUSE -> {
				lastPaused = true
					val notif = buildNotification(this)
					nm.notify(NOTIF_ID, notif)
					UploadChannelBridge.methodChannel?.invokeMethod("nativePause", null)
				// Notify Flutter layer (optional) via broadcast channel -> MethodChannel (invoke from engine context if alive?) Skipped here for simplicity
				START_STICKY
			}
			ACTION_RESUME -> {
				lastPaused = false
					val notif = buildNotification(this)
					nm.notify(NOTIF_ID, notif)
					UploadChannelBridge.methodChannel?.invokeMethod("nativeResume", null)
				START_STICKY
			}
			ACTION_CANCEL -> {
				// Remove notification completely when user cancels
				try { stopForeground(Service.STOP_FOREGROUND_REMOVE) } catch (_: Exception) { stopForeground(STOP_FOREGROUND_DETACH) }
				val nm2 = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
				nm2.cancel(NOTIF_ID)
				stopSelf()
					UploadChannelBridge.methodChannel?.invokeMethod("nativeCancel", null)
					START_NOT_STICKY
				}
				ACTION_CLEAN -> {
					UploadChannelBridge.methodChannel?.invokeMethod("nativeClean", null)
					// Keep notification; maybe show spinner while cleaning
					lastStatus = "running"
					val notif = buildNotification(this)
					nm.notify(NOTIF_ID, notif)
					START_STICKY
				}
				ACTION_TOGGLE_COLLAPSE -> {
					lastCollapsed = !lastCollapsed
					val notif = buildNotification(this)
					nm.notify(NOTIF_ID, notif)
					UploadChannelBridge.methodChannel?.invokeMethod("nativeToggle", mapOf("collapsed" to lastCollapsed))
					START_STICKY
				}
				ACTION_HIDE -> {
					nm.cancel(NOTIF_ID)
					UploadChannelBridge.methodChannel?.invokeMethod("nativeHide", null)
				START_NOT_STICKY
			}
			else -> START_NOT_STICKY
		}
	}
}

class UploadActionReceiver : BroadcastReceiver() {
	override fun onReceive(context: Context, intent: Intent?) {
		val action = intent?.action ?: return
		// Delegate actual UI state change by re-sending intent to service
		val svcIntent = Intent(context, UploadForegroundService::class.java).apply { this.action = action }
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
			context.startForegroundService(svcIntent)
		} else {
			context.startService(svcIntent)
		}
		// Additionally, we could forward to Flutter via a MethodChannel if engine is running (deferred to later step)
	}
}

object UploadChannelBridge {
    @Volatile
    var methodChannel: io.flutter.plugin.common.MethodChannel? = null
}
