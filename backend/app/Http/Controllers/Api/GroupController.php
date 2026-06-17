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

        // ទាញយកតែសសរស្ដម្ភ 'name' (Display Name) ចេញពីតារាង users
        $members = $group->users()->pluck('name'); 

        return response()->json([
            'group_name' => $group->name,
            'members' => $members
        ]);
    }
}