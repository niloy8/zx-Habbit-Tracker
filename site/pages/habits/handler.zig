const std = @import("std");
const zx = @import("zx");

// Goals - daily tasks (separate from habits)
pub const Goal = struct {
    id: u32,
    name: []const u8,
    description: []const u8,
    completed: bool,
};

// A day number (days since epoch) for tracking completions
pub const DayNumber = i32;

// Habits - tracked daily over time with completion history
pub const Habit = struct {
    id: u32,
    name: []const u8,
    description: []const u8,
    created_day: DayNumber, // Day when habit was created
    completed_days: std.ArrayList(DayNumber), // List of days when habit was completed

    // Check if completed on a specific day
    pub fn isCompletedOnDay(self: *const Habit, day: DayNumber) bool {
        for (self.completed_days.items) |completed_day| {
            if (completed_day == day) return true;
        }
        return false;
    }

    // Calculate current streak ending today
    pub fn calculateStreak(self: *const Habit, today: DayNumber) u32 {
        var streak: u32 = 0;
        var check_day = today;

        while (self.isCompletedOnDay(check_day)) {
            streak += 1;
            check_day -= 1;
        }

        return streak;
    }

    // Get days since creation (capped at 30)
    pub fn getDaysSinceCreation(self: *const Habit, today: DayNumber) u32 {
        const diff = today - self.created_day + 1;
        if (diff < 0) return 0;
        if (diff > 30) return 30;
        return @intCast(diff);
    }

    // Get completion status for days since creation (for the grid)
    // Returns array where index 0 is oldest day shown, last index is today
    // Values: 0 = not created yet, 1 = not done, 2 = done
    pub fn getTrackingDays(self: *const Habit, today: DayNumber) [30]u8 {
        var result: [30]u8 = [_]u8{0} ** 30;
        const days_active = self.getDaysSinceCreation(today);

        // Fill from the right (today is rightmost)
        var i: u32 = 0;
        while (i < days_active) : (i += 1) {
            const grid_index = 29 - (days_active - 1 - i);
            const day = self.created_day + @as(DayNumber, @intCast(i));
            result[grid_index] = if (self.isCompletedOnDay(day)) 2 else 1;
        }
        return result;
    }
};

// Helper struct for template use
pub const HabitView = struct {
    id: u32,
    name: []const u8,
    description: []const u8,
    completed_today: bool,
    streak: u32,
    days_active: u32,
    tracking_days: [30]u8, // 0 = not created yet, 1 = not done, 2 = done
};

var goals: std.ArrayList(Goal) = .empty;
var habits: std.ArrayList(Habit) = .empty;
var next_goal_id: u32 = 1;
var next_habit_id: u32 = 1;

// Get current day number (days since Unix epoch)
fn getCurrentDay() DayNumber {
    const timestamp = std.time.timestamp();
    return @intCast(@divFloor(timestamp, 86400)); // seconds per day
}

pub const RequestInfo = struct {
    goals: std.ArrayList(Goal),
    habit_views: []HabitView,
    goals_total: u32,
    goals_completed: u32,
    habits_total: u32,
    habits_completed_today: u32,
    max_streak: u32,
    today: DayNumber,
};

pub fn handleRequest(ctx: zx.PageContext) RequestInfo {
    const qs = ctx.request.query() catch @panic("Query error");
    const today = getCurrentDay();

    var did_action = false;

    // Goal actions
    if (qs.get("goal_name")) |name| {
        const description = qs.get("goal_description") orelse "";
        handleAddGoal(ctx.allocator, name, description);
        did_action = true;
    }

    if (qs.get("toggle_goal")) |id_str| {
        handleToggleGoal(id_str);
        did_action = true;
    }

    if (qs.get("delete_goal")) |id_str| {
        handleDeleteGoal(id_str);
        did_action = true;
    }

    // Habit actions
    if (qs.get("habit_name")) |name| {
        const description = qs.get("habit_description") orelse "";
        handleAddHabit(ctx.allocator, name, description, today);
        did_action = true;
    }

    if (qs.get("toggle_habit")) |id_str| {
        handleToggleHabit(ctx.allocator, id_str, today);
        did_action = true;
    }

    if (qs.get("delete_habit")) |id_str| {
        handleDeleteHabit(id_str);
        did_action = true;
    }

    if (did_action) {
        ctx.response.header("Location", "/habits");
        ctx.response.setStatus(.found);
    }

    const goal_stats = calculateGoalStats();
    const habit_views = buildHabitViews(ctx.allocator, today);
    const habit_stats = calculateHabitStats(today);

    return RequestInfo{
        .goals = goals,
        .habit_views = habit_views,
        .goals_total = goal_stats.total,
        .goals_completed = goal_stats.completed,
        .habits_total = habit_stats.total,
        .habits_completed_today = habit_stats.completed_today,
        .max_streak = habit_stats.max_streak,
        .today = today,
    };
}

// Build view structs for habits with computed values
fn buildHabitViews(allocator: std.mem.Allocator, today: DayNumber) []HabitView {
    var views = allocator.alloc(HabitView, habits.items.len) catch @panic("OOM");

    for (habits.items, 0..) |*habit, i| {
        views[i] = HabitView{
            .id = habit.id,
            .name = habit.name,
            .description = habit.description,
            .completed_today = habit.isCompletedOnDay(today),
            .streak = habit.calculateStreak(today),
            .days_active = habit.getDaysSinceCreation(today),
            .tracking_days = habit.getTrackingDays(today),
        };
    }

    return views;
}

// Goal functions
fn handleAddGoal(allocator: std.mem.Allocator, name: []const u8, description: []const u8) void {
    if (name.len == 0) return;

    const name_copy = allocator.dupe(u8, name) catch @panic("OOM");
    const desc_copy = allocator.dupe(u8, description) catch @panic("OOM");

    const goal = Goal{
        .id = next_goal_id,
        .name = name_copy,
        .description = desc_copy,
        .completed = false,
    };

    next_goal_id += 1;
    goals.append(allocator, goal) catch @panic("OOM");
}

fn handleToggleGoal(id_str: []const u8) void {
    const id = std.fmt.parseInt(u32, id_str, 10) catch return;

    for (goals.items) |*goal| {
        if (goal.id == id) {
            goal.completed = !goal.completed;
            break;
        }
    }
}

fn handleDeleteGoal(id_str: []const u8) void {
    const id = std.fmt.parseInt(u32, id_str, 10) catch return;

    for (goals.items, 0..) |goal, i| {
        if (goal.id == id) {
            _ = goals.orderedRemove(i);
            break;
        }
    }
}

fn calculateGoalStats() struct { total: u32, completed: u32 } {
    var total: u32 = 0;
    var completed: u32 = 0;

    for (goals.items) |goal| {
        total += 1;
        if (goal.completed) {
            completed += 1;
        }
    }

    return .{ .total = total, .completed = completed };
}

// Habit functions
fn handleAddHabit(allocator: std.mem.Allocator, name: []const u8, description: []const u8, today: DayNumber) void {
    if (name.len == 0) return;

    const name_copy = allocator.dupe(u8, name) catch @panic("OOM");
    const desc_copy = allocator.dupe(u8, description) catch @panic("OOM");

    const habit = Habit{
        .id = next_habit_id,
        .name = name_copy,
        .description = desc_copy,
        .created_day = today,
        .completed_days = .empty,
    };

    next_habit_id += 1;
    habits.append(std.heap.page_allocator, habit) catch @panic("OOM");
}

fn handleToggleHabit(allocator: std.mem.Allocator, id_str: []const u8, today: DayNumber) void {
    _ = allocator;
    const id = std.fmt.parseInt(u32, id_str, 10) catch return;

    for (habits.items) |*habit| {
        if (habit.id == id) {
            // Check if already completed today
            var found_index: ?usize = null;
            for (habit.completed_days.items, 0..) |day, i| {
                if (day == today) {
                    found_index = i;
                    break;
                }
            }

            if (found_index) |idx| {
                // Remove today from completed days (un-complete)
                _ = habit.completed_days.orderedRemove(idx);
            } else {
                // Add today to completed days
                habit.completed_days.append(std.heap.page_allocator, today) catch @panic("OOM");
            }
            break;
        }
    }
}

fn handleDeleteHabit(id_str: []const u8) void {
    const id = std.fmt.parseInt(u32, id_str, 10) catch return;

    for (habits.items, 0..) |*habit, i| {
        if (habit.id == id) {
            habit.completed_days.deinit(std.heap.page_allocator);
            _ = habits.orderedRemove(i);
            break;
        }
    }
}

fn calculateHabitStats(today: DayNumber) struct { total: u32, completed_today: u32, max_streak: u32 } {
    var total: u32 = 0;
    var completed_today: u32 = 0;
    var max_streak: u32 = 0;

    for (habits.items) |*habit| {
        total += 1;
        if (habit.isCompletedOnDay(today)) {
            completed_today += 1;
        }
        const streak = habit.calculateStreak(today);
        if (streak > max_streak) {
            max_streak = streak;
        }
    }

    return .{ .total = total, .completed_today = completed_today, .max_streak = max_streak };
}
