<?php
namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Series;
use App\Models\Episode;
use App\Models\Notification;
use App\Models\CoinPackage;
use Illuminate\Support\Facades\DB;

class DashboardController extends Controller
{
    public function index() {
        $stats = [
            'series_count' => Series::count(),
            'episodes_count' => Episode::count(),
            'notifications_sent' => Notification::count(),
            'coin_packages' => CoinPackage::count(),
        ];

        return view('admin.dashboard', compact('stats'));
    }
}