<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        Schema::create('admob_configs', function (Blueprint $table) {
            $table->id();
            $table->string('app_id')->default('main');
            $table->string('banner_ad_unit')->nullable();
            $table->string('interstitial_ad_unit')->nullable();
            $table->string('rewarded_ad_unit')->nullable();
            $table->boolean('is_active')->default(true);
            $table->timestamps();
            $table->unique(['app_id']);
        });
    }
    public function down(): void { Schema::dropIfExists('admob_configs'); }
};