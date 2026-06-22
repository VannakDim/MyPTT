<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Group;
use Illuminate\Http\Request;

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
}