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
Route::post('/messages', [\App\Http\Controllers\Api\MessageController::class, 'store']);
Route::post('/messages/seen', [\App\Http\Controllers\Api\MessageController::class, 'markSeen']);

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
    Route::post('/upload-chunk', [\App\Http\Controllers\Api\MessageController::class, 'uploadChunk']);
    Route::get('/groups/{id}/messages', [\App\Http\Controllers\Api\MessageController::class, 'index']);
    Route::put('/profile', [\App\Http\Controllers\Api\UserController::class, 'updateProfile']);
    Route::delete('/messages/{id}', [\App\Http\Controllers\Api\MessageController::class, 'destroy']);
    Route::delete('/messages', [\App\Http\Controllers\Api\MessageController::class, 'batchDestroy']);

    // User Management for Admins Only
    Route::middleware(\App\Http\Middleware\AdminMiddleware::class)->group(function () {
        Route::post('/backup', [\App\Http\Controllers\Api\UserController::class, 'backupDatabase']);
        Route::get('/users', [\App\Http\Controllers\Api\UserController::class, 'index']);
        Route::post('/users', [\App\Http\Controllers\Api\UserController::class, 'store']);
        Route::put('/users/{id}', [\App\Http\Controllers\Api\UserController::class, 'update']);
        Route::delete('/users/{id}', [\App\Http\Controllers\Api\UserController::class, 'destroy']);
        Route::get('/all-groups', [\App\Http\Controllers\Api\UserController::class, 'getGroups']);
        Route::post('/groups', [\App\Http\Controllers\Api\GroupController::class, 'store']);
        Route::put('/groups/{id}', [\App\Http\Controllers\Api\GroupController::class, 'update']);
        Route::delete('/groups/{id}', [\App\Http\Controllers\Api\GroupController::class, 'destroy']);
    });
});