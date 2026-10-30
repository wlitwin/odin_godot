package replay_cavecrawl
import gd "godot:godot"
import rgd "godot:replay/godot"

@(gd_method)
replay_cave_moderation_probe :: proc(self:^ReplayCave,key:string)->gd.Int {
 switch key {
 case "removed":return gd.Int(self.moderation.removed)
 case "pending":return gd.Int(self.moderation.pending)
 case "phase":return gd.Int(self.room.removal.phase)
 case "epoch":return gd.Int(self.room.lease.view.epoch)
 case "owner":return gd.Int(self.room.lease.view.owner.member)
 case "nominee":return gd.Int(self.room.backup_observation.nominee.member)
 case "prepared":return gd.Int(self.room.backup_observation.prepared)
 case "member2_enabled":for member in self.room.members {if member.identity.member==2 {return gd.Int(member.enabled)}};return -1
 case "ban_count":return self.session.authority ? gd.Int(self.session.server.banned_count) : -1
 }
 return -1
}
@(gd_method)
replay_cave_moderation_handoff :: proc(self:^ReplayCave)->bool {return rgd.room_handoff(&self.room)==.None}
