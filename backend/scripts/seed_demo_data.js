// Seeds ONE account with a month of realistic demo data so a fresh user
// (or a reviewer) can see every screen populated: goals + milestones,
// ~37 tasks across the month (completed / in progress / overdue / upcoming),
// ~33 backdated focus sessions for the charts, daily reflections and a few
// past weekly reviews.
//
// Nothing here touches any OTHER user, and the account itself must already
// exist (register through the app or the API first — password hashes are
// only ever created by the auth service).
//
//   node scripts/seed_demo_data.js                            # default demo email
//   node scripts/seed_demo_data.js someone@example.com        # other account
//   node scripts/seed_demo_data.js --force                    # wipe + reseed
//
// Focus sessions are inserted directly (with historical timestamps)
// because the public API derives duration from the server clock and
// deliberately refuses to backdate — history must be written once, here.
require('dotenv').config();
const { pool } = require('../src/config/db');

const args = process.argv.slice(2);
const FORCE = args.includes('--force');
const EMAIL = (args.find((a) => !a.startsWith('--')) || 'dguzumaki005@gmail.com').toLowerCase();

const DAY = 86400000;
// All offsets are relative to "today" (UTC), so the data always ends today.
const dateStr = (offset) => new Date(Date.now() + offset * DAY).toISOString().slice(0, 10);
const tsAt = (offset, hhmm) => {
  const [h, m] = hhmm.split(':').map(Number);
  const d = new Date(Date.now() + offset * DAY);
  d.setUTCHours(h, m, 0, 0);
  return d.toISOString();
};

// ---------- data ----------------------------------------------------------

const PROFILE = {
  shortDescription: 'Building things, running miles, reading books.',
  mainGoal: 'Ship the portfolio, break 55 minutes in the 10K, read 12 books.',
  dailyAvailableTime: '2 hours',
  growthAreas: ['Career', 'Learning', 'Fitness'],
};

const GOALS = [
  { key: 'run', name: 'Run a 10K under 55 minutes', description: 'Twelve weeks of easy miles, tempo work and a long run every Sunday.', why: 'Proof that consistent training pays off — and feeling strong again.', area: 'Fitness', targetOffset: 52, status: 'active', progress: 40, createdOffset: -32 },
  { key: 'portfolio', name: 'Ship my portfolio v2', description: 'A fresh site with three deep case studies, deployed on my own domain.', why: 'Better work should bring better opportunities next quarter.', area: 'Career', targetOffset: 36, status: 'active', progress: 65, createdOffset: -31 },
  { key: 'books', name: 'Read 12 books this year', description: 'Two books a month, with notes after every chapter.', why: 'Reading keeps my thinking honest and my writing sharp.', area: 'Learning', targetOffset: 67, status: 'active', progress: 50, createdOffset: -30 },
  { key: 'meditate', name: 'Meditate every morning for 30 days', description: 'Ten slow minutes right after waking up.', why: 'Calmer mornings make calmer workdays.', area: 'Personal', targetOffset: -4, status: 'completed', progress: 100, createdOffset: -35 },
];

const MILESTONES = [
  { key: 'run1', goal: 'run', title: 'Build base mileage to 25 km/week', status: 'completed', pos: 0 },
  { key: 'run2', goal: 'run', title: 'Complete four tempo runs', status: 'completed', pos: 1 },
  { key: 'run3', goal: 'run', title: 'Race a local 10K', status: 'pending', pos: 2 },
  { key: 'port1', goal: 'portfolio', title: 'Rewrite three case studies', status: 'completed', pos: 0 },
  { key: 'port2', goal: 'portfolio', title: 'New responsive project grid', status: 'in_progress', pos: 1 },
  { key: 'port3', goal: 'portfolio', title: 'Deploy on my own domain', status: 'pending', pos: 2 },
  { key: 'book1', goal: 'books', title: 'Finish six books', status: 'completed', pos: 0 },
  { key: 'book2', goal: 'books', title: 'Finish three more books', status: 'in_progress', pos: 1 },
  { key: 'book3', goal: 'books', title: 'Finish the final three books', status: 'pending', pos: 2 },
];

// st = status, due = due-date offset, c = created offset, ms = milestone key
const TASKS = [
  // — running —
  { t: 'Easy 5K recovery run', d: 'Conversational pace, flat route.', due: -30, p: 'medium', min: 45, cat: 'Fitness', st: 'completed', g: 'run', ms: 'run1', c: -33 },
  { t: 'Tempo run: 6 km at threshold', d: 'Warm up 10 min, then hold comfortably hard pace.', due: -26, p: 'high', min: 50, cat: 'Fitness', st: 'completed', g: 'run', ms: 'run2', c: -30 },
  { t: 'Strength session: legs', d: 'Squats, lunges, calf raises — 3 sets each.', due: -23, p: 'medium', min: 40, cat: 'Fitness', st: 'completed', g: 'run', ms: null, c: -27 },
  { t: 'Long run 14 km', d: 'Sunday long run, easy effort, hydrate well.', due: -20, p: 'medium', min: 90, cat: 'Fitness', st: 'completed', g: 'run', ms: 'run1', c: -24 },
  { t: 'Easy shakeout run', d: 'Short and slow the day after the long run.', due: -17, p: 'low', min: 30, cat: 'Fitness', st: 'completed', g: 'run', ms: null, c: -21 },
  { t: 'Tempo run: 8 km', d: 'Progress the middle 5 km.', due: -14, p: 'high', min: 60, cat: 'Fitness', st: 'completed', g: 'run', ms: 'run2', c: -18 },
  { t: 'Mobility and stretching', d: 'Hips, hamstrings, calves — 20 focused minutes.', due: -12, p: 'low', min: 20, cat: 'Health', st: 'completed', g: null, ms: null, c: -14 },
  { t: 'Long run 16 km', d: 'Add two km to last week.', due: -9, p: 'medium', min: 100, cat: 'Fitness', st: 'completed', g: 'run', ms: 'run1', c: -13 },
  { t: 'Track intervals 6x400m', d: '90 sec jog recovery between reps.', due: -6, p: 'high', min: 50, cat: 'Fitness', st: 'completed', g: 'run', ms: 'run2', c: -10 },
  { t: "Plan next week's runs", d: 'Sketch the week in the training log.', due: -2, p: 'low', min: 15, cat: 'Personal', st: 'completed', g: 'run', ms: null, c: -3 },
  { t: 'Tempo run: 10 km', d: 'Key session of the week — negative split.', due: 1, p: 'high', min: 60, cat: 'Fitness', st: 'in_progress', g: 'run', ms: 'run2', c: -4 },
  { t: 'Long run 18 km', d: 'Final long run before the taper.', due: 3, p: 'medium', min: 110, cat: 'Fitness', st: 'pending', g: 'run', ms: null, c: -4 },
  { t: 'Buy proper running shoes', d: 'Get gait analysis at the running store.', due: 5, p: 'medium', min: 30, cat: 'Health', st: 'pending', g: null, ms: null, c: -6 },
  // — portfolio —
  { t: 'Draft case study: Dashboard redesign', d: 'Problem, process, decisions, results.', due: -28, p: 'high', min: 90, cat: 'Work', st: 'completed', g: 'portfolio', ms: 'port1', c: -31 },
  { t: 'Export project screenshots', d: 'Retina exports, consistent crops.', due: -24, p: 'medium', min: 45, cat: 'Work', st: 'completed', g: 'portfolio', ms: null, c: -27 },
  { t: 'Rewrite "About me" section', d: 'Short, specific, one clear sentence per idea.', due: -21, p: 'medium', min: 40, cat: 'Work', st: 'completed', g: 'portfolio', ms: 'port1', c: -25 },
  { t: 'Set up new repository structure', d: 'Static site generator, clean content folder.', due: -18, p: 'medium', min: 60, cat: 'Work', st: 'completed', g: 'portfolio', ms: null, c: -22 },
  { t: 'Portfolio grid layout (desktop)', d: 'Responsive card grid with case study previews.', due: -13, p: 'high', min: 120, cat: 'Work', st: 'completed', g: 'portfolio', ms: 'port2', c: -17 },
  { t: 'Portfolio grid layout (mobile)', d: 'Same grid, touch-friendly at every breakpoint.', due: -10, p: 'high', min: 100, cat: 'Work', st: 'completed', g: 'portfolio', ms: 'port2', c: -14 },
  { t: 'Write two new case studies', d: 'Commerce app and analytics dashboard.', due: -7, p: 'high', min: 150, cat: 'Work', st: 'completed', g: 'portfolio', ms: 'port1', c: -12 },
  { t: 'Collect testimonials from clients', d: 'Ask three past collaborators for two lines each.', due: -4, p: 'medium', min: 45, cat: 'Work', st: 'completed', g: 'portfolio', ms: null, c: -8 },
  { t: 'Dark mode pass on all pages', d: 'Check contrast on every surface.', due: 2, p: 'medium', min: 90, cat: 'Work', st: 'in_progress', g: 'portfolio', ms: 'port2', c: -5 },
  { t: 'Buy domain and set up hosting', d: 'Compare registrars, point DNS, enable HTTPS.', due: 6, p: 'high', min: 60, cat: 'Work', st: 'pending', g: 'portfolio', ms: 'port3', c: -5 },
  { t: 'Ask three friends for feedback', d: 'Five-minute screenshare each.', due: 8, p: 'low', min: 30, cat: 'Work', st: 'pending', g: 'portfolio', ms: 'port3', c: -5 },
  // — learning —
  { t: 'Read "Deep Work" chapters 1-4', d: 'Phone in another room while reading.', due: -27, p: 'medium', min: 120, cat: 'Learning', st: 'completed', g: 'books', ms: 'book1', c: -30 },
  { t: 'Finish "Deep Work"', d: 'Last chapter plus the conclusion.', due: -19, p: 'medium', min: 180, cat: 'Learning', st: 'completed', g: 'books', ms: 'book1', c: -23 },
  { t: 'Read "Atomic Habits" chapters 1-5', d: 'Highlight one idea per chapter.', due: -15, p: 'medium', min: 120, cat: 'Learning', st: 'completed', g: 'books', ms: 'book1', c: -18 },
  { t: 'Finish "Atomic Habits"', d: 'Write the summary card afterwards.', due: -8, p: 'medium', min: 150, cat: 'Learning', st: 'completed', g: 'books', ms: 'book1', c: -11 },
  { t: 'Take notes on current book', d: 'Turn highlights into five bullet takeaways.', due: -1, p: 'low', min: 45, cat: 'Learning', st: 'pending', g: 'books', ms: 'book2', c: -4 },
  { t: 'Finish "The Creative Act"', d: 'Roughly 60 pages left.', due: 4, p: 'medium', min: 180, cat: 'Learning', st: 'pending', g: 'books', ms: 'book2', c: -6 },
  { t: 'Spanish vocabulary: 20 minutes', d: 'Review the daily deck.', due: 0, p: 'low', min: 20, cat: 'Learning', st: 'pending', g: null, ms: null, c: -6 },
  { t: 'Finish "Four Thousand Weeks"', d: 'Start it right after the current book.', due: 9, p: 'medium', min: 120, cat: 'Learning', st: 'pending', g: 'books', ms: 'book3', c: -6 },
  // — personal / health —
  { t: 'Meal prep for the week', d: 'Chop veggies, cook protein, portion it out.', due: -5, p: 'medium', min: 75, cat: 'Health', st: 'completed', g: null, ms: null, c: -6 },
  { t: 'Morning meditation: 20 minutes', d: 'Guided breathing, right after coffee.', due: 0, p: 'low', min: 20, cat: 'Personal', st: 'in_progress', g: null, ms: null, c: -6 },
  { t: 'Weekly review and plan the week', d: 'Close the loops, pick the three big things.', due: -1, p: 'medium', min: 30, cat: 'Personal', st: 'completed', g: null, ms: null, c: -2 },
  { t: 'Water the plants and tidy the desk', d: 'A clear desk, a clear head.', due: -3, p: 'low', min: 20, cat: 'Personal', st: 'pending', g: null, ms: null, c: -7 },
  { t: 'Schedule dentist appointment', d: 'Six-month check-up.', due: 7, p: 'low', min: 15, cat: 'Personal', st: 'pending', g: null, ms: null, c: -7 },
];

const SUBTASKS = [
  { task: 'Draft case study: Dashboard redesign', items: [['Outline the story arc', true], ['Pick six screenshots', true], ['Write the results section', false]] },
  { task: 'Write two new case studies', items: [['Commerce app write-up', true], ['Analytics dashboard write-up', true], ['Proofread both', true]] },
  { task: 'Portfolio grid layout (mobile)', items: [['Breakpoints for phone and tablet', true], ['Touch target audit', false]] },
  { task: 'Buy domain and set up hosting', items: [['Compare registrars', false], ['Point DNS and enable HTTPS', false]] },
  { task: 'Long run 18 km', items: [['Lay out gear the night before', false], ['Refill hydration belt', false]] },
];

// Focus history: one session most days, two on some, all completed with a
// server-shaped duration. Morning slots sit at 03:30Z (≈ 09:00 IST) and
// evening slots at 10:30Z (≈ 16:00 IST) so the timestamps look natural.
const SESSIONS = [
  { d: -30, s: '03:30', min: 45, task: 'Easy 5K recovery run', r: 'good' },
  { d: -29, s: '10:30', min: 60, task: 'Draft case study: Dashboard redesign', r: 'excellent', ref: 'Flow state — the outline wrote itself.' },
  { d: -28, s: '03:30', min: 120, task: 'Read "Deep Work" chapters 1-4', r: 'good' },
  { d: -27, s: '10:30', min: 45, task: 'Export project screenshots', r: 'okay', pause: 180 },
  { d: -26, s: '03:30', min: 50, task: 'Tempo run: 6 km at threshold', r: 'good' },
  { d: -26, s: '10:30', min: 60, task: null, r: 'okay' },
  { d: -25, s: '10:30', min: 45, task: null, r: 'good' },
  { d: -24, s: '03:30', min: 40, task: 'Strength session: legs', r: 'okay' },
  { d: -23, s: '10:30', min: 90, task: 'Draft case study: Dashboard redesign', r: 'good' },
  { d: -22, s: '03:30', min: 45, task: null, r: 'excellent' },
  { d: -21, s: '10:30', min: 40, task: 'Rewrite "About me" section', r: 'good' },
  { d: -20, s: '03:30', min: 90, task: 'Long run 14 km', r: 'excellent' },
  { d: -19, s: '10:30', min: 180, task: 'Finish "Deep Work"', r: 'good', ref: 'Finished the book — best non-fiction this year.' },
  { d: -18, s: '03:30', min: 60, task: 'Set up new repository structure', r: 'okay' },
  { d: -17, s: '03:30', min: 30, task: 'Easy shakeout run', r: 'good' },
  { d: -16, s: '10:30', min: 60, task: null, r: 'okay', pause: 300 },
  { d: -15, s: '10:30', min: 120, task: 'Read "Atomic Habits" chapters 1-5', r: 'good' },
  { d: -14, s: '03:30', min: 60, task: 'Tempo run: 8 km', r: 'excellent' },
  { d: -13, s: '10:30', min: 120, task: 'Portfolio grid layout (desktop)', r: 'excellent', ref: 'The grid finally clicked — shipped the desktop version.' },
  { d: -12, s: '03:30', min: 20, task: 'Mobility and stretching', r: 'okay' },
  { d: -11, s: '10:30', min: 45, task: null, r: 'low', ref: 'Distracted the whole hour — too many tabs open.' },
  { d: -10, s: '10:30', min: 100, task: 'Portfolio grid layout (mobile)', r: 'good' },
  { d: -9, s: '03:30', min: 100, task: 'Long run 16 km', r: 'good' },
  { d: -8, s: '10:30', min: 150, task: 'Finish "Atomic Habits"', r: 'excellent', ref: 'Habit stacking actually stuck this time.' },
  { d: -7, s: '10:30', min: 150, task: 'Write two new case studies', r: 'good' },
  { d: -6, s: '03:30', min: 50, task: 'Track intervals 6x400m', r: 'good' },
  { d: -5, s: '10:30', min: 75, task: 'Meal prep for the week', r: 'okay' },
  { d: -4, s: '10:30', min: 45, task: 'Collect testimonials from clients', r: 'okay' },
  { d: -3, s: '03:30', min: 60, task: null, r: 'good' },
  { d: -2, s: '10:30', min: 30, task: "Plan next week's runs", r: 'good' },
  { d: -1, s: '10:30', min: 45, task: 'Take notes on current book', r: 'okay', pause: 240 },
  { d: 0, s: '03:30', min: 60, task: null, r: 'good', ref: 'Slow start, but the morning block worked.' },
  { d: 0, s: '10:30', min: 30, task: null, r: 'good' },
];

const REFLECTIONS = [
  { d: -29, well: 'Wrote the first case study draft without overthinking it.', hard: 'Checked email far too often.', imp: 'Batch email to two fixed times a day.' },
  { d: -26, well: 'Held the tempo pace the whole run.', hard: 'Woke up tired and dragged myself out.', imp: 'Lights out before 11 PM on run nights.' },
  { d: -23, well: 'Two solid deep-work blocks before lunch.', hard: 'Afternoon slump hit hard at 3 PM.', imp: 'Walk instead of coffee after lunch.' },
  { d: -19, well: 'Finished "Deep Work" and my running felt easier.', hard: 'Merging branch conflicts ate an hour.', imp: 'Keep feature branches smaller.' },
  { d: -15, well: 'Grid layout finally came together.', hard: 'Multitasked through a design review.', imp: 'One meeting, one notebook, no tabs.' },
  { d: -12, well: 'Shipped both case studies to review.', hard: 'Skipped my evening stretching.', imp: 'Stretch right after the laptop closes.' },
  { d: -8, well: 'Best focus week so far — 9 hours of deep work.', hard: 'Sunday long run started too late.', imp: 'Run before breakfast on Sundays.' },
  { d: -5, well: 'Meal prep made the whole week calmer.', hard: 'Slipped on the meditation streak.', imp: 'Meditate before opening Slack.' },
  { d: -2, well: 'Weekly review surfaced the three things that matter.', hard: 'Overcommitted on Thursday.', imp: 'Cap the day at three big tasks.' },
  { d: -1, well: 'Closed the week proud of the progress.', hard: 'Phone first thing in the morning.', imp: 'Charge the phone outside the bedroom.' },
];

// Past weeks only (Mondays). The current week is left empty on purpose so
// the AI weekly review feature has something to generate.
const WEEKLY_REVIEWS = [
  { weekOffset: -21, summary: 'A strong base week: four runs, two deep-work blocks a day, and the about-page rewrite.', win: 'Ran 16 km without stopping and finished "Deep Work".', attention: 'Evening screen time crept back up.', next: 'Add the second tempo run and start the grid layout.' },
  { weekOffset: -14, summary: 'Mostly steady — the portfolio grid took shape and reading stayed on track.', win: 'Desktop grid shipped and looked right on every breakpoint.', attention: 'Two days with no focus session at all.', next: 'Finish the mobile grid and keep one session daily.' },
  { weekOffset: -7, summary: 'Best week of the month: two case studies written, intervals done, 9 hours of deep work.', win: 'Wrote and published both new case studies.', attention: 'Thursday was overloaded with small tasks.', next: 'Dark mode pass, testimonials, and a 16+ km long run.' },
];

// ---------- seeding -------------------------------------------------------

async function main() {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const userRes = await client.query('SELECT id FROM users WHERE email = $1', [EMAIL]);
    if (userRes.rowCount === 0) {
      throw new Error(
        `No account for ${EMAIL}. Register it first (in the app or via POST /api/auth/register), then re-run this script.`
      );
    }
    const userId = userRes.rows[0].id;

    const existing = await client.query(
      `SELECT (SELECT count(*) FROM goals WHERE user_id = $1)::int AS goals,
              (SELECT count(*) FROM tasks WHERE user_id = $1)::int AS tasks,
              (SELECT count(*) FROM focus_sessions WHERE user_id = $1)::int AS sessions`,
      [userId]
    );
    const counts = existing.rows[0];
    if ((counts.goals || counts.tasks || counts.sessions) > 0) {
      if (!FORCE) {
        throw new Error(
          `${EMAIL} already has ${counts.goals} goal(s), ${counts.tasks} task(s) and ${counts.sessions} session(s). ` +
            'Re-run with --force to wipe them and reseed.'
        );
      }
      // Children first where there is no cascade (focus_sessions/task_id
      // and tasks/goal_id are ON DELETE SET NULL, so order still matters
      // for a clean slate).
      await client.query('DELETE FROM subtasks WHERE task_id IN (SELECT id FROM tasks WHERE user_id = $1)', [userId]);
      await client.query('DELETE FROM focus_sessions WHERE user_id = $1', [userId]);
      await client.query('DELETE FROM reflections WHERE user_id = $1', [userId]);
      await client.query('DELETE FROM weekly_reviews WHERE user_id = $1', [userId]);
      await client.query('DELETE FROM tasks WHERE user_id = $1', [userId]);
      await client.query('DELETE FROM milestones WHERE goal_id IN (SELECT id FROM goals WHERE user_id = $1)', [userId]);
      await client.query('DELETE FROM goals WHERE user_id = $1', [userId]);
      console.log(`Cleared existing data for ${EMAIL}.`);
    }

    // Profile: personalisation answers + setup completed (so the app goes
    // straight to Home instead of the onboarding wizard).
    await client.query(
      `UPDATE profiles SET short_description = $2, main_goal = $3, daily_available_time = $4,
              growth_areas = $5, setup_completed = TRUE, updated_at = NOW()
       WHERE user_id = $1`,
      [userId, PROFILE.shortDescription, PROFILE.mainGoal, PROFILE.dailyAvailableTime, PROFILE.growthAreas]
    );

    // Goals
    const goalIds = {};
    for (const g of GOALS) {
      const r = await client.query(
        `INSERT INTO goals (user_id, name, description, why_it_matters, growth_area, target_date,
                            status, progress, created_at, updated_at)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$9) RETURNING id`,
        [userId, g.name, g.description, g.why, g.area, dateStr(g.targetOffset), g.status, g.progress, tsAt(g.createdOffset, '08:00')]
      );
      goalIds[g.key] = r.rows[0].id;
    }

    // Milestones
    const milestoneIds = {};
    for (const m of MILESTONES) {
      const r = await client.query(
        `INSERT INTO milestones (goal_id, title, position, status, created_at, updated_at)
         VALUES ($1,$2,$3,$4,$5,$5) RETURNING id`,
        [goalIds[m.goal], m.title, m.pos, m.status, tsAt(-28, '08:10')]
      );
      milestoneIds[m.key] = r.rows[0].id;
    }

    // Tasks
    const taskIds = {};
    for (const t of TASKS) {
      const created = tsAt(t.c, '08:30');
      const completed = t.st === 'completed' ? tsAt(t.due, '19:00') : null;
      const r = await client.query(
        `INSERT INTO tasks (user_id, goal_id, milestone_id, title, description, due_date, priority,
                            estimated_minutes, category, status, completed_at, created_at, updated_at)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$12)
         RETURNING id`,
        [userId, t.g ? goalIds[t.g] : null, t.ms ? milestoneIds[t.ms] : null, t.t, t.d,
         dateStr(t.due), t.p, t.min, t.cat, t.st, completed, created]
      );
      taskIds[t.t] = r.rows[0].id;
    }

    // Subtasks
    let subtaskCount = 0;
    for (const s of SUBTASKS) {
      const taskId = taskIds[s.task];
      if (!taskId) continue;
      for (let i = 0; i < s.items.length; i++) {
        const [title, done] = s.items[i];
        await client.query(
          `INSERT INTO subtasks (task_id, title, is_completed, position, created_at, updated_at)
           VALUES ($1,$2,$3,$4,$5,$5)`,
          [taskId, title, done, i, tsAt(-6, '09:00')]
        );
        subtaskCount++;
      }
    }

    // Focus sessions — backdated history (see header comment).
    let sessionCount = 0;
    for (const s of SESSIONS) {
      const started = new Date(tsAt(s.d, s.s));
      const pause = s.pause || 0;
      const ended = new Date(started.getTime() + s.min * 60000 + pause * 1000);
      await client.query(
        `INSERT INTO focus_sessions (user_id, task_id, started_at, ended_at, duration_seconds,
                                     productivity_rating, reflection, status, total_pause_seconds, created_at)
         VALUES ($1,$2,$3,$4,$5,$6,$7,'completed',$8,$3)`,
        [userId, s.task ? taskIds[s.task] || null : null, started.toISOString(), ended.toISOString(),
         s.min * 60, s.r, s.ref || null, pause]
      );
      sessionCount++;
    }

    // Daily reflections
    for (const r of REFLECTIONS) {
      await client.query(
        `INSERT INTO reflections (user_id, reflection_date, went_well, was_difficult, to_improve, created_at, updated_at)
         VALUES ($1,$2,$3,$4,$5,$6,$6)
         ON CONFLICT (user_id, reflection_date) DO NOTHING`,
        [userId, dateStr(r.d), r.well, r.hard, r.imp, tsAt(r.d, '21:00')]
      );
    }

    // Weekly reviews for PAST weeks (Monday-based).
    const mondayOffset = -((new Date().getDay() + 6) % 7);
    for (const w of WEEKLY_REVIEWS) {
      const start = dateStr(mondayOffset + w.weekOffset);
      const end = dateStr(mondayOffset + w.weekOffset + 6);
      await client.query(
        `INSERT INTO weekly_reviews (user_id, week_start, week_end, summary, biggest_win,
                                     needs_attention, next_week_focus, created_at, updated_at)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$8)
         ON CONFLICT (user_id, week_start) DO NOTHING`,
        [userId, start, end, w.summary, w.win, w.attention, w.next, tsAt(mondayOffset + w.weekOffset + 6, '20:00')]
      );
    }

    await client.query('COMMIT');
    console.log(`Seeded ${EMAIL}:`);
    console.log(`  goals      ${GOALS.length}`);
    console.log(`  milestones ${MILESTONES.length}`);
    console.log(`  tasks      ${TASKS.length}`);
    console.log(`  subtasks   ${subtaskCount}`);
    console.log(`  sessions   ${sessionCount} (last 30 days, all completed)`);
    console.log(`  reflections ${REFLECTIONS.length}`);
    console.log(`  weekly reviews ${WEEKLY_REVIEWS.length} (past weeks only)`);
    console.log(`  period     ${dateStr(-35)} → ${dateStr(0)}`);
  } catch (err) {
    await client.query('ROLLBACK').catch(() => {});
    throw err;
  } finally {
    client.release();
    await pool.end().catch(() => {});
  }
}

main().catch((err) => {
  console.error('SEED FAILED:', err.message);
  process.exit(1);
});
