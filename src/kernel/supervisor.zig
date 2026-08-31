const jmptbl = @import("velox_jumptable");
const assert = @import("testing.zig").assert;

var last_game_state: u32 = 0;
var current_task_id: u32 = 0;

pub fn gameStateDidUpdate(newState: u32) bool {
    const didChange = newState != last_game_state;
    last_game_state = newState;
    return didChange;
}

pub fn runCompStateTask(status: u32) void {
    if ((status & 0b101) == 1) {
        // disabled
    }
}

test "game state update with same state" {
    last_game_state = 0b011;
    assert(gameStateDidUpdate(0b011) == 0);
}

test "game state update with different state" {
    last_game_state = 0b000;
    assert(gameStateDidUpdate(0b011) == 1);
}
