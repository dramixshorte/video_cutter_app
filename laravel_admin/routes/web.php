<?php
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Admin\DashboardController;
use App\Http\Controllers\Admin\SeriesController;
use App\Http\Controllers\Admin\EpisodeController;
use App\Http\Controllers\Admin\SettingsController;
use App\Http\Controllers\Admin\NotificationController;
use App\Http\Controllers\Auth\LoginController;
use App\Models\ActivityLog;
use Illuminate\Http\Request;

// Authentication
Route::get('/login', [LoginController::class, 'show'])->name('login.form');
Route::post('/login', [LoginController::class, 'login'])->name('login.attempt');
Route::post('/logout', [LoginController::class, 'logout'])->name('logout');

Route::middleware('auth')->group(function () {
    Route::get('/', [DashboardController::class, 'index'])->name('admin.dashboard');

    Route::prefix('series')->name('admin.series.')->group(function () {
        Route::get('/', [SeriesController::class, 'index'])->name('index');
        Route::get('/create', [SeriesController::class, 'create'])->name('create');
        Route::post('/', [SeriesController::class, 'store'])->name('store');
        Route::get('/{series}/edit', [SeriesController::class, 'edit'])->name('edit');
        Route::put('/{series}', [SeriesController::class, 'update'])->name('update');
        Route::delete('/{series}', [SeriesController::class, 'destroy'])->name('destroy');

        Route::prefix('{series}/episodes')->name('episodes.')->group(function () {
            Route::get('/', [EpisodeController::class, 'index'])->name('index');
            Route::get('/create', [EpisodeController::class, 'create'])->name('create');
            Route::post('/', [EpisodeController::class, 'store'])->name('store');
            Route::get('/{episode}/edit', [EpisodeController::class, 'edit'])->name('edit');
            Route::put('/{episode}', [EpisodeController::class, 'update'])->name('update');
            Route::delete('/{episode}', [EpisodeController::class, 'destroy'])->name('destroy');
        });
    });

    Route::get('settings', [SettingsController::class, 'index'])->name('admin.settings.index');
    Route::post('settings', [SettingsController::class, 'store'])->name('admin.settings.store');
    Route::delete('settings/{setting}', [SettingsController::class, 'destroy'])->name('admin.settings.destroy');

    Route::prefix('notifications')->name('admin.notifications.')->group(function () {
        Route::get('/', [NotificationController::class, 'index'])->name('index');
        Route::get('/create', [NotificationController::class, 'create'])->name('create');
        Route::post('/', [NotificationController::class, 'store'])->name('store');
    });

    Route::get('/activity', function(Request $request){
        $logs = ActivityLog::with('user')->latest()->paginate(40);
        return view('admin.activity.index', compact('logs'));
    })->name('admin.activity.index');
});