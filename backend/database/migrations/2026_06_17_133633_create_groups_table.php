<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
# database/migrations/xxxx_xx_xx_create_groups_table.php
    public function up()
    {
        Schema::create('groups', function (Blueprint $table) {
            $table->id();
            $table->string('name')->unique(); # ឧទាហរណ៍៖ "security", "control_room"
            $table->string('display_name');  # ឧទាហរណ៍៖ "ក្រុមសន្តិសុខ", "បន្ទប់បញ្ជា"
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('groups');
    }
};
