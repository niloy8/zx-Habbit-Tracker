const std = @import("std");
const zx = @import("zx");

pub const Habit = struct {
    id: u32,
    name: []const u8,
    description: []const u8,
    completed: bool,
    streak: u32,
};

var habits: std.ArrayList(Habit) = .empty;
var next_id: u32 = 1;

pub const RequestInfo = struct {
    is_add: bool,
    is_toggle: bool,
    is_delete: bool,
    habits: std.ArrayList(Habit),
    active_count: u32,
    completed_count: u32,
    max_streak: u32,
};

pub fn handleRequest(ctx: zx.PageContext) RequestInfo {
    const qs = ctx.request.query() catch @panic("Query error");

    const is_add = qs.get("name") != null;
    const is_toggle = qs.get("toggle") != null;
    const is_delete = qs.get("delete") != null;

    if (is_add) {
        if (qs.get("name")) |name| {
            const description = qs.get("description") orelse "";
            handleAddHabit(ctx.allocator, name, description);
        }
    }

    if (is_toggle) {
        if (qs.get("toggle")) |toggle_id_str| {
            handleToggleHabit(toggle_id_str);
        }
    }

    if (is_delete) {
        if (qs.get("delete")) |delete_id_str| {
            handleDeleteHabit(delete_id_str);
        }
    }

    const stats = calculateStats();

    if (is_add or is_toggle or is_delete) {
        ctx.response.header("Location", "/habits");
        ctx.response.setStatus(.found);
    }

    return RequestInfo{
        .is_add = is_add,
        .is_toggle = is_toggle,
        .is_delete = is_delete,
        .habits = habits,
        .active_count = stats.active,
        .completed_count = stats.completed,
        .max_streak = stats.max_streak,
    };
}

fn handleAddHabit(allocator: std.mem.Allocator, name: []const u8, description: []const u8) void {
    if (name.len == 0) return;

    const name_copy = allocator.dupe(u8, name) catch @panic("OOM");
    const desc_copy = allocator.dupe(u8, description) catch @panic("OOM");

    const habit = Habit{
        .id = next_id,
        .name = name_copy,
        .description = desc_copy,
        .completed = false,
        .streak = 0,
    };

    next_id += 1;
    habits.append(allocator, habit) catch @panic("OOM");
}

fn handleToggleHabit(toggle_id_str: []const u8) void {
    const toggle_id = std.fmt.parseInt(u32, toggle_id_str, 10) catch return;

    for (habits.items) |*habit| {
        if (habit.id == toggle_id) {
            habit.completed = !habit.completed;
            if (habit.completed) {
                habit.streak += 1;
            }
            break;
        }
    }
}

fn handleDeleteHabit(delete_id_str: []const u8) void {
    const delete_id = std.fmt.parseInt(u32, delete_id_str, 10) catch return;

    for (habits.items, 0..) |habit, i| {
        if (habit.id == delete_id) {
            _ = habits.orderedRemove(i);
            break;
        }
    }
}

fn calculateStats() struct { active: u32, completed: u32, max_streak: u32 } {
    var active: u32 = 0;
    var completed: u32 = 0;
    var max_streak: u32 = 0;

    for (habits.items) |habit| {
        if (!habit.completed) {
            active += 1;
        } else {
            completed += 1;
        }
        if (habit.streak > max_streak) {
            max_streak = habit.streak;
        }
    }

    return .{ .active = active, .completed = completed, .max_streak = max_streak };
}
