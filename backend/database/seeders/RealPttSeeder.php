<?php

namespace Database\Seeders;

use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;
use App\Models\User;
use App\Models\Group;
use Illuminate\Support\Facades\Hash;

class RealPttSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run()
    {
        // ១. បង្កើតក្រុមគំរូ ២
        $groupSecurity = Group::create([
            'name' => 'security',
            'display_name' => 'ក្រុមសន្តិសុខទូទៅ'
        ]);

        $groupControl = Group::create([
            'name' => 'control_room',
            'display_name' => 'បន្ទប់បញ្ជាការ'
        ]);

        // ២. បង្កើតគណនីអ្នកប្រើប្រាស់គំរូ ៣ នាក់ (បើមាន admin រួចហើយ វានឹងមិនបង្កើតជាន់ទេ)
        $admin = User::firstOrCreate(
            ['email' => 'admin@gmail.com'],
            ['name' => 'admin', 'password' => Hash::make('password'), 'role' => 'admin']
        );

        $user01 = User::firstOrCreate(
            ['email' => 'security_01@gmail.com'],
            ['name' => 'security_01', 'password' => Hash::make('password')]
        );

        $user02 = User::firstOrCreate(
            ['email' => 'security_02@gmail.com'],
            ['name' => 'security_02', 'password' => Hash::make('password')]
        );

        // ៣. ភ្ជាប់ទំនាក់ទំនង៖ ឱ្យគ្រប់គ្នាចូលក្នុងក្រុម Security និង Control Room
        $groupSecurity->users()->sync([$admin->id, $user01->id, $user02->id]);
        $groupControl->users()->sync([$admin->id, $user02->id]); // ក្នុងបន្ទប់បញ្ជាមានតែ admin និង user_02
    }
}
