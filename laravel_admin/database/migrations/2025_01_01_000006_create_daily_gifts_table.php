<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        Schema::create('daily_gifts', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->unsignedInteger('day_number');
            $table->unsignedInteger('coins');
            $table->boolean('is_active')->default(true);
            $table->string('app_id')->default('main');
            $table->timestamps();
            $table->unique(['app_id', 'day_number']);
        });
    }
    public function down(): void { Schema::dropIfExists('daily_gifts'); }
};