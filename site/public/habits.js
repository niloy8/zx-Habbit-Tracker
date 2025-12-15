// Habit storage (in-memory for now)
let habits = [];
let nextId = 1;

// Mobile menu toggle
document.addEventListener('DOMContentLoaded', function () {
    const mobileMenuBtn = document.getElementById('mobile-menu-btn');
    const mobileMenu = document.getElementById('mobile-menu');

    if (mobileMenuBtn && mobileMenu) {
        mobileMenuBtn.addEventListener('click', function () {
            mobileMenu.classList.toggle('hidden');
        });
    }

    const form = document.getElementById('habit-form');
    if (form) {
        form.addEventListener('submit', function (e) {
            e.preventDefault();

            const name = form.querySelector('input[name="name"]').value.trim();
            const description = form.querySelector('textarea[name="description"]').value.trim();

            if (name) {
                addHabit(name, description);
                form.reset();
                document.getElementById('add-modal').classList.add('hidden');
            }
        });
    }

    // Load habits on page load
    updateHabitsList();
    updateStats();
});

function addHabit(name, description) {
    const habit = {
        id: nextId++,
        name: name,
        description: description,
        completed: false,
        streak: 0,
        completionRate: 0
    };

    habits.push(habit);
    updateHabitsList();
    updateStats();
}

function toggleHabit(button) {
    const habitElement = button.closest('.habit-item');
    const habitId = parseInt(habitElement.dataset.habitId);
    const habit = habits.find(h => h.id === habitId);

    if (habit) {
        habit.completed = !habit.completed;
        if (habit.completed) {
            habit.streak++;
        }
        updateHabitsList();
        updateStats();
    }
}

function deleteHabit(button) {
    const habitElement = button.closest('.habit-item');
    const habitId = parseInt(habitElement.dataset.habitId);

    if (confirm('Are you sure you want to delete this habit?')) {
        habits = habits.filter(h => h.id !== habitId);
        updateHabitsList();
        updateStats();
    }
}

function updateHabitsList() {
    const container = document.getElementById('habits-list');
    if (!container) return;

    if (habits.length === 0) {
        container.innerHTML = `
            <div class="text-center py-16">
                <div class="w-20 h-20 bg-gray-900 rounded-full flex items-center justify-center mx-auto mb-4 border-2 border-gray-700">
                    <svg class="w-8 h-8 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
                    </svg>
                </div>
                <h3 class="text-xl font-semibold text-gray-400 mb-2">No habits yet</h3>
                <p class="text-gray-500 mb-6">Start building better habits by adding your first one</p>
                <button onclick="document.getElementById('add-modal').classList.remove('hidden')" class="px-6 py-3 bg-gradient-to-r from-purple-600 to-blue-600 text-white rounded-lg font-semibold hover:shadow-lg transition-all cursor-pointer">
                    Create Your First Habit
                </button>
            </div>
        `;
        return;
    }

    container.innerHTML = habits.map(habit => `
        <div class="habit-item bg-gray-900 rounded-xl p-6 border border-gray-700 hover:border-${habit.completed ? 'purple' : 'blue'}-500 transition-all group" data-habit-id="${habit.id}">
            <div class="flex items-center justify-between">
                <div class="flex items-center gap-4 flex-1">
                    <button onclick="toggleHabit(this)" class="w-12 h-12 rounded-full border-2 ${habit.completed ? 'border-purple-500 bg-purple-500' : 'border-gray-600 hover:border-purple-500 hover:bg-purple-500/20'} transition-all flex items-center justify-center group-hover:scale-110 cursor-pointer">
                        <svg class="w-6 h-6 ${habit.completed ? 'text-white' : 'text-gray-600 hidden'}" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M5 13l4 4L19 7" />
                        </svg>
                    </button>
                    <div class="flex-1">
                        <h3 class="text-xl font-semibold text-white mb-1">${habit.name}</h3>
                        ${habit.description ? `<p class="text-sm text-gray-400 mb-2">${habit.description}</p>` : ''}
                        <div class="flex items-center gap-4 text-sm text-gray-400">
                            <span class="flex items-center gap-1">
                                <svg class="w-4 h-4 text-orange-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                    <path d="M8.5 14.5A2.5 2.5 0 0 0 11 12c0-1.38-.5-2-1-3-1.072-2.143-.224-4.054 2-6 .5 2.5 2 4.9 4 6.5 2 1.6 3 3.5 3 5.5a7 7 0 1 1-14 0c0-1.153.433-2.294 1-3a2.5 2.5 0 0 0 2.5 2.5z" />
                                </svg>
                                <span>${habit.streak} day streak</span>
                            </span>
                        </div>
                    </div>
                </div>
                <button onclick="deleteHabit(this)" class="p-2 text-red-400 hover:bg-red-900/20 rounded-lg transition-colors cursor-pointer">
                    <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                    </svg>
                </button>
            </div>
        </div>
    `).join('');
}

function updateStats() {
    const activeCount = habits.length;
    const completedToday = habits.filter(h => h.completed).length;
    const maxStreak = habits.length > 0 ? Math.max(...habits.map(h => h.streak)) : 0;

    const activeEl = document.getElementById('active-count');
    const completedEl = document.getElementById('completed-count');
    const streakEl = document.getElementById('current-streak');

    if (activeEl) activeEl.textContent = activeCount;
    if (completedEl) completedEl.textContent = completedToday;
    if (streakEl) streakEl.textContent = maxStreak;
}
