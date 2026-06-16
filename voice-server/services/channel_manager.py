from fastapi import WebSocket
import json

class ChannelManager:
    def __init__(self):
        # ទម្រង់ទិន្នន័យ៖ { "បន្ទប់": {"users": {websocket_obj: username}, "speaker": None} }
        self.channels = {}

    async def update_user_count(self, channel: str):
        """ 🎯 ផ្ញើចំនួនសមាជិកបច្ចុប្បន្ន និងបញ្ជីឈ្មោះ (រាប់តែឈ្មោះប្លែកគ្នា - Unique Users) """
        if channel in self.channels:
            unique_usernames = list(set(self.channels[channel]["users"].values()))
            payload = {
                "type": "user_count",
                "count": len(unique_usernames),
                "user_list": unique_usernames
            }
            for user_ws in self.channels[channel]["users"].keys():
                try:
                    await user_ws.send_text(json.dumps(payload))
                except Exception:
                    pass

    async def connect(self, channel: str, websocket: WebSocket, username: str):
        if channel not in self.channels:
            self.channels[channel] = {"users": {}, "speaker": None}
        self.channels[channel]["users"][websocket] = username
        await self.update_user_count(channel)

    async def disconnect(self, channel: str, websocket: WebSocket):
        if channel in self.channels:
            if websocket in self.channels[channel]["users"]:
                del self.channels[channel]["users"][websocket]
                if self.channels[channel]["speaker"] == websocket:
                    self.channels[channel]["speaker"] = None
                if len(self.channels[channel]["users"]) == 0:
                    del self.channels[channel]
                else:
                    await self.update_user_count(channel)

    async def request_ptt(self, channel: str, websocket: WebSocket) -> bool:
        """ សុំសិទ្ធិនិយាយ PTT """
        if channel in self.channels and self.channels[channel]["speaker"] is None:
            self.channels[channel]["speaker"] = websocket
            return True
        return False

    async def release_ptt(self, channel: str, websocket: WebSocket) -> bool:
        """ លែងដៃឈប់និយាយ PTT """
        if channel in self.channels and self.channels[channel]["speaker"] == websocket:
            self.channels[channel]["speaker"] = None
            return True
        return False

    async def broadcast_audio(self, channel: str, sender_ws: WebSocket, audio_bytes: bytes):
        """ 🎯 បញ្ជូនគ្រាប់សំឡេងទៅកាន់អ្នកដទៃ (គាំទ្រទាំង PTT និងប្រព័ន្ធ Call រួមគ្នា) """
        if channel in self.channels:
            is_ptt_speaker = self.channels[channel]["speaker"] == sender_ws
            is_line_free = self.channels[channel]["speaker"] is None
            
            # បើគាត់កំពុងកាន់សោរ PTT ឬខ្សែទំនេរ (ស្ថានភាពលេង mode Call) ទើបអនុញ្ញាតឱ្យសំឡេងឆ្លងកាត់
            if is_ptt_speaker or is_line_free:
                for user_ws in self.channels[channel]["users"].keys():
                    if user_ws != sender_ws:
                        try:
                            await user_ws.send_bytes(audio_bytes)
                        except Exception:
                            pass

    async def broadcast_text(self, channel: str, data_dict: dict):
        if channel in self.channels:
            for user_ws in self.channels[channel]["users"].keys():
                try:
                    await user_ws.send_text(json.dumps(data_dict))
                except Exception:
                    pass

    async def send_to_user(self, channel: str, target_username: str, data_dict: dict):
        """ ផ្ញើសារចំគោលដៅទៅកាន់ User ម្នាក់ជាក់លាក់ (សម្រាប់ប្រព័ន្ធ Call) """
        if channel in self.channels:
            for user_ws, name in self.channels[channel]["users"].items():
                if name == target_username:
                    try:
                        await user_ws.send_text(json.dumps(data_dict))
                    except Exception:
                        pass