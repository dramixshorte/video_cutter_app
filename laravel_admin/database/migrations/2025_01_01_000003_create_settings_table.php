<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        Schema::create('settings', function (Blueprint $table) {
            $table->id();
            $table->string('app_id')->default('main');
            $table->string('key');
            $table->text('value')->nullable();
            $table->timestamps();
            $table->unique(['app_id', 'key']);
        });
    }
    public function down(): void { Schema::dropIfExists('settings'); }
};