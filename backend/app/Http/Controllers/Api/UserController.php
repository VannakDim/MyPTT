<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Models\Group;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rule;
use App\Helpers\VoiceServer;

class UserController extends Controller
{
    /**
     * Display a listing of the resource.
     */
    public function index()
    {
        return response()->json(User::with('groups')->get());
    }

    /**
     * Store a newly created resource in storage.
     */
    public function store(Request $request)
    {
        $request->validate([
            'name' => 'required|string|max:255',
            'email' => 'required|string|email|max:255|unique:users',
            'password' => 'required|string|min:6',
            'role' => ['required', Rule::in(['admin', 'user'])],
            'avatar' => 'nullable|string',
            'groups' => 'array',
        ]);

        $user = User::create([
            'name' => $request->name,
            'email' => $request->email,
            'password' => Hash::make($request->password),
            'role' => $request->role,
            'avatar' => $request->avatar,
        ]);

        if ($request->has('groups')) {
            $user->groups()->sync($request->groups);
        }

        VoiceServer::broadcast([
            'type' => 'user_update',
            'user_id' => $user->id,
            'action' => 'created'
        ]);

        return response()->json([
            'status' => 'success',
            'user' => $user->load('groups')
        ]);
    }

    /**
     * Update the specified resource in storage.
     */
    public function update(Request $request, $id)
    {
        $user = User::findOrFail($id);

        $request->validate([
            'name' => 'required|string|max:255',
            'email' => ['required', 'string', 'email', 'max:255', Rule::unique('users')->ignore($user->id)],
            'password' => 'nullable|string|min:6',
            'role' => ['required', Rule::in(['admin', 'user'])],
            'avatar' => 'nullable|string',
            'groups' => 'array',
        ]);

        $user->name = $request->name;
        $user->email = $request->email;
        $user->role = $request->role;
        $user->avatar = $request->avatar;

        if ($request->filled('password')) {
            $user->password = Hash::make($request->password);
        }

        $user->save();

        if ($request->has('groups')) {
            $user->groups()->sync($request->groups);
        }

        VoiceServer::broadcast([
            'type' => 'user_update',
            'user_id' => $user->id,
            'action' => 'updated'
        ]);

        return response()->json([
            'status' => 'success',
            'user' => $user->load('groups')
        ]);
    }

    /**
     * Remove the specified resource from storage.
     */
    public function destroy(Request $request, $id)
    {
        $user = User::findOrFail($id);

        // Prevent admin from deleting themselves
        if ($request->user()->id === $user->id) {
            return response()->json([
                'status' => 'error',
                'message' => 'Cannot delete your own administrator account.'
            ], 400);
        }

        // Detach groups first (pivot table cleanup)
        $user->groups()->detach();
        
        $userId = $user->id;
        $user->delete();

        VoiceServer::broadcast([
            'type' => 'user_update',
            'user_id' => $userId,
            'action' => 'deleted'
        ]);

        return response()->json([
            'status' => 'success',
            'message' => 'User deleted successfully.'
        ]);
    }

    /**
     * Get all available groups.
     */
    public function getGroups()
    {
        return response()->json(Group::withCount('users')->get());
    }

    /**
     * Update the authenticated user's profile.
     */
    public function updateProfile(Request $request)
    {
        $user = $request->user();

        $request->validate([
            'name' => 'required|string|max:255',
            'email' => ['required', 'string', 'email', 'max:255', Rule::unique('users')->ignore($user->id)],
            'password' => 'nullable|string|min:6',
            'avatar' => 'nullable|string',
        ]);

        $user->name = $request->name;
        $user->email = $request->email;
        $user->avatar = $request->avatar;

        if ($request->filled('password')) {
            $user->password = Hash::make($request->password);
        }

        $user->save();

        VoiceServer::broadcast([
            'type' => 'user_update',
            'user_id' => $user->id,
            'action' => 'updated'
        ]);

        return response()->json([
            'status' => 'success',
            'user' => $user
        ]);
    }

    /**
     * Backup database and stream it to the user.
     */
    public function backupDatabase(Request $request)
    {
        $tables = [];
        $result = \DB::select("SHOW TABLES");
        
        $dbName = env('DB_DATABASE', 'real_db');
        
        foreach ($result as $row) {
            $rowArr = (array)$row;
            $tableName = reset($rowArr);
            $tables[] = $tableName;
        }

        $sql = "-- Database Backup for MyPTT\n";
        $sql .= "-- Generated: " . now()->toDateTimeString() . "\n\n";
        $sql .= "SET FOREIGN_KEY_CHECKS=0;\n\n";

        foreach ($tables as $table) {
            $createTableRes = \DB::select("SHOW CREATE TABLE `{$table}`");
            if (empty($createTableRes)) continue;
            $createTableArr = (array)$createTableRes[0];
            $createTableSql = $createTableArr['Create Table'] ?? $createTableArr['create table'] ?? '';
            
            $sql .= "DROP TABLE IF EXISTS `{$table}`;\n";
            $sql .= $createTableSql . ";\n\n";

            $rows = \DB::table($table)->get();
            if ($rows->count() > 0) {
                $sql .= "LOCK TABLES `{$table}` WRITE;\n";
                $sql .= "ALTER TABLE `{$table}` DISABLE KEYS;\n";
                
                foreach ($rows as $row) {
                    $rowArr = (array)$row;
                    $keys = array_map(function($key) {
                        return "`{$key}`";
                    }, array_keys($rowArr));
                    
                    $values = array_map(function($value) {
                        if ($value === null) {
                            return 'NULL';
                        }
                        return "'" . addslashes($value) . "'";
                    }, array_values($rowArr));

                    $sql .= "INSERT INTO `{$table}` (" . implode(', ', $keys) . ") VALUES (" . implode(', ', $values) . ");\n";
                }
                
                $sql .= "ALTER TABLE `{$table}` ENABLE KEYS;\n";
                $sql .= "UNLOCK TABLES;\n\n";
            }
        }

        $sql .= "SET FOREIGN_KEY_CHECKS=1;\n";

        $fileName = 'backup_' . now()->format('Y-m-d_H-i-s') . '.sql';

        return response($sql, 200, [
            'Content-Type' => 'application/octet-stream',
            'Content-Disposition' => 'attachment; filename="' . $fileName . '"',
        ]);
    }
}
