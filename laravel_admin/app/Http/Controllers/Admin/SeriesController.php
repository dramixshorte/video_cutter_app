<?php
namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Series;
use Illuminate\Http\Request;

class SeriesController extends Controller
{
    public function index() {
        $series = Series::query()->orderBy('order_index')->paginate(20);
        return view('admin.series.index', compact('series'));
    }

    public function create() { return view('admin.series.create'); }

    public function store(Request $request) {
        $data = $request->validate([
            'title' => 'required|string|max:255',
            'description' => 'nullable|string',
            'order_index' => 'nullable|integer',
            'is_active' => 'nullable|boolean'
        ]);
        $data['app_id'] = $request->get('app_id','main');
        Series::create($data);
        return redirect()->route('admin.series.index')->with('status','Series created');
    }

    public function edit(Series $series) { return view('admin.series.edit', compact('series')); }

    public function update(Request $request, Series $series) {
        $data = $request->validate([
            'title' => 'required|string|max:255',
            'description' => 'nullable|string',
            'order_index' => 'nullable|integer',
            'is_active' => 'nullable|boolean'
        ]);
        $series->update($data);
        return redirect()->route('admin.series.index')->with('status','Series updated');
    }

    public function destroy(Series $series) {
        $series->delete();
        return redirect()->route('admin.series.index')->with('status','Series deleted');
    }
}