<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Group;
use Illuminate\Http\Request;
use App\Helpers\VoiceServer;

class GroupController extends Controller
{

    // ១. ហៅយកបញ្ជីក្រុមទាំងអស់ដែល User នោះមានសិទ្ធិចូលរួម
    public function myGroups(Request $request)
    {
        $user = $request->user(); // ចាប់យក User តាមរយៈ Bearer Token
        $groups = $user->groups()->select('groups.id', 'name', 'display_name')->get();
        
        return response()->json($groups);
    }

    // ២. ហៅយកបញ្ជីឈ្មោះសមាជិកទាំងអស់នៅក្នុងក្រុមជាក់លាក់ណាមួយ
    public function groupMembers($groupId)
    {
        $group = Group::find($groupId);
        if (!$group) {
            return response()->json(['message' => 'រកមិនឃើញក្រុមនេះទេ'], 404);
        }

        // ទាញយកទិន្នន័យ User ទាំងអស់ + avatar ចេញពីតារាង users
        $members = $group->users()->select('users.id', 'users.name', 'users.email', 'users.role', 'users.avatar')->get();

        // Return ជា plain array ផ្ទាល់ (ងាយ parse ក្នុង Flutter)
        return response()->json($members);
    }

    // ៣. បង្កើតក្រុមថ្មី (សម្រាប់ Admin)
    public function store(Request $request)
    {
        $request->validate([
            'name' => 'required|string|max:255|unique:groups,name',
            'display_name' => 'required|string|max:255',
        ]);

        $group = Group::create([
            'name' => $request->name,
            'display_name' => $request->display_name,
        ]);

        VoiceServer::broadcast([
            'type' => 'groups_update',
            'group_id' => $group->id,
            'action' => 'created'
        ]);

        return response()->json([
            'status' => 'success',
            'group' => $group
        ], 201);
    }

    // ៤. កែប្រែព័ត៌មានក្រុម (សម្រាប់ Admin)
    public function update(Request $request, $id)
    {
        $group = Group::findOrFail($id);

        $request->validate([
            'name' => 'required|string|max:255|unique:groups,name,' . $group->id,
            'display_name' => 'required|string|max:255',
        ]);

        $group->update([
            'name' => $request->name,
            'display_name' => $request->display_name,
        ]);

        VoiceServer::broadcast([
            'type' => 'groups_update',
            'group_id' => $group->id,
            'action' => 'updated'
        ]);

        return response()->json([
            'status' => 'success',
            'group' => $group
        ]);
    }

    // ៥. លុបក្រុម (សម្រាប់ Admin)
    public function destroy($id)
    {
        $group = Group::findOrFail($id);

        // Detach all users first (pivot table cleanup)
        $group->users()->detach();
        
        // Also delete messages related to this group
        $group->messages()->delete();
        
        $groupId = $group->id;
        $group->delete();

        VoiceServer::broadcast([
            'type' => 'groups_update',
            'group_id' => $groupId,
            'action' => 'deleted'
        ]);

        return response()->json([
            'status' => 'success',
            'message' => 'លុបក្រុមបានជោគជ័យ'
        ]);
    }
}