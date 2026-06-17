<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\GroupController;

/*
|--------------------------------------------------------------------------
| API Routes
|--------------------------------------------------------------------------
*/

// 1. Route សាធារណៈ (Public Route) មិនទាមទារ Token ទេ ព្រោះប្រើសម្រាប់ Login យក Token
Route::post('/login', [AuthController::class, 'login']);

// 2. ក្រុម Route ដែលការពារដោយ Sanctum (ទាល់តែមាន Token ទើបហៅបាន)
Route::middleware('auth:sanctum')->group(function () {
    
    // Route សម្រាប់ Check Token (FastAPI នឹងហៅមកកាន់ Route មួយនេះ)
    Route::get('/user', function (Request $request) {
        return $request->user();
    });
    
    // អ្នកអាចបន្ថែម Route ផ្សេងៗទៀតដែលត្រូវការ Token នៅទីនេះបាន...
    // ឧទាហរណ៍៖ Route::get('/channels', [ChannelController::class, 'index']);

    Route::get('/my-groups', [GroupController::class, 'myGroups']);
    Route::get('/groups/{id}/members', [GroupController::class, 'groupMembers']);
    
});