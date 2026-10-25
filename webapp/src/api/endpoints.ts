// Typed calls for every GRIVIO endpoint the web app uses, with the single
// snake_case → camelCase mapping layer (mirrors the Flutter models).
import { api } from './client';
import type {
  AIWeeklyReview,
  BreakdownProposal,
  DailyPlan,
  FocusSession,
  Goal,
  Milestone,
  Profile,
  ProgressData,
  Reflection,
  Subtask,
  SubtaskSuggestion,
  Task,
  TaskImprovement,
  User,
  WeeklyReview,
  WeeklyStats,
} from '../types';

const num = (v: unknown): number | null => (v == null ? null : Math.round(Number(v)));
const str = (v: unknown): string | null => (v == null ? null : String(v));
// 'YYYY-MM-DD' kept as-is (no Date parsing — avoids timezone day-shifts).
const date = (v: unknown): string | null => {
  if (v == null) return null;
  const s = String(v);
  return s.length >= 10 ? s.slice(0, 10) : s;
};

// ---- mapping helpers ----
export const mapTask = (j: any): Task => ({
  id: j.id,
  title: j.title ?? '',
  description: str(j.description),
  dueDate: date(j.due_date),
  priority: (j.priority ?? 'medium') as Task['priority'],
  estimatedMinutes: num(j.estimated_minutes),
  category: str(j.category),
  status: (j.status ?? 'pending') as Task['status'],
  goalId: str(j.goal_id),
  milestoneId: str(j.milestone_id),
  goalName: str(j.goal_name),
  milestoneTitle: str(j.milestone_title),
  subtaskCount: num(j.subtask_count) ?? 0,
  completedSubtasks: num(j.completed_subtasks) ?? 0,
});

const mapSubtask = (j: any): Subtask => ({
  id: j.id,
  taskId: j.task_id ?? '',
  title: j.title ?? '',
  isCompleted: !!j.is_completed,
  position: num(j.position) ?? 0,
});

export const mapGoal = (j: any): Goal => ({
  id: j.id,
  name: j.name ?? '',
  description: str(j.description),
  whyItMatters: str(j.why_it_matters),
  growthArea: str(j.growth_area),
  targetDate: date(j.target_date),
  status: (j.status ?? 'active') as Goal['status'],
  progress: num(j.progress) ?? 0,
  milestoneCount: num(j.milestone_count) ?? 0,
  completedMilestones: num(j.completed_milestones) ?? 0,
});

const mapMilestone = (j: any): Milestone => ({
  id: j.id,
  goalId: j.goal_id ?? '',
  title: j.title ?? '',
  description: str(j.description),
  position: num(j.position) ?? 0,
  status: (j.status ?? 'pending') as Milestone['status'],
});

const mapSession = (j: any): FocusSession => ({
  id: j.id,
  taskId: str(j.task_id),
  taskTitle: str(j.task_title),
  startedAt: j.started_at,
  endedAt: str(j.ended_at),
  durationSeconds: num(j.duration_seconds),
  status: (j.status ?? 'active') as FocusSession['status'],
  pausedAt: str(j.paused_at),
  totalPauseSeconds: num(j.total_pause_seconds) ?? 0,
  productivityRating: str(j.productivity_rating),
  reflection: str(j.reflection),
});

export const mapProfile = (j: any): Profile => ({
  name: j.name ?? '',
  profilePicture: str(j.profile_picture),
  shortDescription: str(j.short_description),
  growthAreas: Array.isArray(j.growth_areas) ? j.growth_areas.map(String) : [],
  mainGoal: str(j.main_goal),
  dailyAvailableTime: str(j.daily_available_time),
  setupCompleted: !!j.setup_completed,
});

// ---- auth ----
export async function register(name: string, email: string, password: string) {
  const r = await api.post<{ user: User; token: string }>('/auth/register', {
    name,
    email,
    password,
  });
  return r;
}

export async function login(email: string, password: string) {
  const r = await api.post<{ user: User; token: string }>('/auth/login', { email, password });
  return r;
}

export const fetchMe = () => api.get<{ user: User }>('/auth/me').then((r) => r.user);
export const logoutServer = () => api.post('/auth/logout');

// ---- profile ----
export const fetchProfile = () =>
  api.get<{ profile: unknown }>('/profile').then((r) => mapProfile(r.profile));

export const updateProfile = (fields: Record<string, unknown>) =>
  api
    .put<{ profile: unknown }>('/profile', fields)
    .then((r) => mapProfile(r.profile));

// ---- goals & milestones ----
export async function listGoals(status?: string): Promise<Goal[]> {
  const q = status ? `?status=${status}` : '';
  const r = await api.get<{ goals: any[] }>(`/goals${q}`);
  return (r.goals ?? []).map(mapGoal);
}

export const fetchGoal = (id: string) =>
  api.get<{ goal: unknown }>(`/goals/${id}`).then((r) => mapGoal(r.goal));

export const createGoal = (fields: Record<string, unknown>) =>
  api.post<{ goal: unknown }>('/goals', fields).then((r) => mapGoal(r.goal));

export const updateGoal = (id: string, fields: Record<string, unknown>) =>
  api.put<{ goal: unknown }>(`/goals/${id}`, fields).then((r) => mapGoal(r.goal));

export const deleteGoal = (id: string) => api.del(`/goals/${id}`);

export async function listMilestones(goalId: string): Promise<Milestone[]> {
  const r = await api.get<{ milestones: any[] }>(`/goals/${goalId}/milestones`);
  return (r.milestones ?? []).map(mapMilestone);
}

export const createMilestone = (goalId: string, fields: Record<string, unknown>) =>
  api
    .post<{ milestone: unknown }>(`/goals/${goalId}/milestones`, fields)
    .then((r) => mapMilestone(r.milestone));

export const updateMilestone = (id: string, fields: Record<string, unknown>) =>
  api
    .put<{ milestone: unknown }>(`/milestones/${id}`, fields)
    .then((r) => mapMilestone(r.milestone));

export const deleteMilestone = (id: string) => api.del(`/milestones/${id}`);

// ---- tasks & subtasks ----
export async function listTasks(params: { status?: string; goalId?: string } = {}): Promise<Task[]> {
  const q = new URLSearchParams();
  if (params.status) q.set('status', params.status);
  if (params.goalId) q.set('goalId', params.goalId);
  const qs = q.toString();
  const r = await api.get<{ tasks: any[] }>(`/tasks${qs ? `?${qs}` : ''}`);
  return (r.tasks ?? []).map(mapTask);
}

export const fetchTask = (id: string) =>
  api.get<{ task: unknown }>(`/tasks/${id}`).then((r) => mapTask(r.task));

export const createTask = (fields: Record<string, unknown>) =>
  api.post<{ task: unknown }>('/tasks', fields).then((r) => mapTask(r.task));

export const updateTask = (id: string, fields: Record<string, unknown>) =>
  api.put<{ task: unknown }>(`/tasks/${id}`, fields).then((r) => mapTask(r.task));

export const setTaskStatus = (id: string, status: string) =>
  api.patch<{ task: unknown }>(`/tasks/${id}/status`, { status }).then((r) => mapTask(r.task));

export const deleteTask = (id: string) => api.del(`/tasks/${id}`);

export async function listSubtasks(taskId: string): Promise<Subtask[]> {
  const r = await api.get<{ subtasks: any[] }>(`/tasks/${taskId}/subtasks`);
  return (r.subtasks ?? []).map(mapSubtask);
}

export const createSubtask = (taskId: string, title: string) =>
  api
    .post<{ subtask: unknown }>(`/tasks/${taskId}/subtasks`, { title })
    .then((r) => mapSubtask(r.subtask));

export const updateSubtask = (id: string, fields: Record<string, unknown>) =>
  api
    .put<{ subtask: unknown }>(`/subtasks/${id}`, fields)
    .then((r) => mapSubtask(r.subtask));

export const deleteSubtask = (id: string) => api.del(`/subtasks/${id}`);

// ---- focus sessions ----
export async function listSessions(): Promise<FocusSession[]> {
  const r = await api.get<{ sessions: any[] }>('/focus/sessions');
  return (r.sessions ?? []).map(mapSession);
}

export const startSession = (taskId: string | null) =>
  api
    .post<{ session: unknown }>('/focus/sessions', taskId ? { task_id: taskId } : {})
    .then((r) => mapSession(r.session));

export const pauseSession = (id: string) =>
  api.patch<{ session: unknown }>(`/focus/sessions/${id}/pause`).then((r) => mapSession(r.session));

export const resumeSession = (id: string) =>
  api
    .patch<{ session: unknown }>(`/focus/sessions/${id}/resume`)
    .then((r) => mapSession(r.session));

export const completeSession = (id: string, rating?: string | null, reflection?: string | null) =>
  api
    .patch<{ session: unknown }>(`/focus/sessions/${id}/complete`, {
      ...(rating ? { productivity_rating: rating.toLowerCase() } : {}),
      ...(reflection ? { reflection } : {}),
    })
    .then((r) => mapSession(r.session));

export const cancelSession = (id: string) =>
  api
    .patch<{ session: unknown }>(`/focus/sessions/${id}/cancel`)
    .then((r) => mapSession(r.session));

// ---- progress, weekly reviews, reflections ----
// range must be one of the backend's accepted values: week | month | 3months.
export async function fetchProgress(range = 'week'): Promise<ProgressData> {
  const r = await api.get<any>(`/progress?range=${range}`);
  return {
    range: r.range ?? range,
    summary: {
      tasksCompleted: num(r.summary?.tasksCompleted) ?? 0,
      focusMinutes: num(r.summary?.focusMinutes) ?? 0,
      completionRate: num(r.summary?.completionRate) ?? 0,
      activeGoals: num(r.summary?.activeGoals) ?? 0,
    },
    // The backend sends `count` for taskTrend and `minutes` for
    // focusTrend (see progress.service.js) — both normalized to the
    // web's `value` field so every chart reads one shape. Dates are
    // trimmed to YYYY-MM-DD so heatmap cells, streaks and weekday
    // labels key the same way locally-built dates do.
    taskTrend: (r.taskTrend ?? []).map((t: any) => ({
      date: String(t.date).slice(0, 10),
      value: num(t.count) ?? num(t.value) ?? 0,
    })),
    focusTrend: (r.focusTrend ?? []).map((t: any) => ({
      date: String(t.date).slice(0, 10),
      value: num(t.minutes) ?? num(t.value) ?? 0,
    })),
    goalProgress: (r.goalProgress ?? []).map((g: any) => ({
      id: g.id,
      name: g.name ?? '',
      progress: num(g.progress) ?? 0,
      targetDate: date(g.targetDate ?? g.target_date),
    })),
    insights: Array.isArray(r.insights) ? r.insights.map(String) : [],
  };
}

export async function fetchWeek(weekStart: string) {
  const r = await api.get<{ stats: WeeklyStats; review: WeeklyReview | null }>(
    `/weekly-reviews/week/${weekStart}`,
  );
  return r;
}

export async function listReviews(): Promise<WeeklyReview[]> {
  const r = await api.get<{ reviews: WeeklyReview[] }>('/weekly-reviews');
  return r.reviews ?? [];
}

export const saveWeeklyReview = (fields: Record<string, unknown>) =>
  api.post<{ review: WeeklyReview }>('/weekly-reviews', fields).then((r) => r.review);

export async function fetchReflection(dateStr: string): Promise<Reflection | null> {
  const r = await api.get<any>(`/reflections?date=${dateStr}`);
  const list = r.reflections ?? [];
  if (!list.length) return null;
  const j = list[0];
  return {
    id: j.id,
    date: date(j.date) ?? dateStr,
    wentWell: str(j.wentWell ?? j.went_well),
    wasDifficult: str(j.wasDifficult ?? j.was_difficult),
    toImprove: str(j.toImprove ?? j.to_improve),
  };
}

export const saveReflection = (dateStr: string, fields: Record<string, string>) =>
  api
    .post<{ reflection: any }>('/reflections', { date: dateStr, ...fields })
    .then((r) => r.reflection as Reflection);

// ---- AI (server-side Groq; preview-only: generating never writes data) ----
export async function aiSubtasks(taskId: string, instructions: string) {
  const r = await api.post<any>('/ai/subtasks/generate', {
    taskId,
    instructions: instructions.trim(),
  });
  return (r.data?.suggestions ?? []) as SubtaskSuggestion[];
}

export async function aiImprove(payload: Record<string, unknown>) {
  const r = await api.post<any>('/ai/tasks/improve', payload);
  return (r.data ?? {}) as TaskImprovement;
}

export async function aiBreakdown(payload: Record<string, unknown>) {
  const r = await api.post<any>('/ai/breakdown/generate', payload);
  return (r.data ?? { phases: [] }) as BreakdownProposal;
}

export async function aiDailyPlan(payload: Record<string, unknown>) {
  const r = await api.post<any>('/ai/daily-plan/generate', payload);
  const d = r.data;
  if (!d) return null;
  // JSON keys differ from field names (scheduledTasks → scheduled,
  // unscheduledTasks → unscheduled) — the same mapping the mobile
  // DailyPlan.fromJson performs. Absent lists become empty ones so the
  // modal can never crash rendering the result.
  return {
    ...d,
    scheduled: (d.scheduled ?? d.scheduledTasks ?? []) as DailyPlan['scheduled'],
    unscheduled: (d.unscheduled ?? d.unscheduledTasks ?? []) as DailyPlan['unscheduled'],
    breaks: (d.breaks ?? []) as DailyPlan['breaks'],
    warnings: (d.warnings ?? []) as DailyPlan['warnings'],
    // AI task proposals (only sent when the user has no open tasks);
    // preview-only until the user explicitly picks them.
    suggestedTasks: (d.suggestedTasks ?? []) as DailyPlan['suggestedTasks'],
  } as DailyPlan;
}

export async function aiWeeklyReview(weekStart: string) {
  const r = await api.post<any>('/ai/weekly-review/generate', { weekStart });
  return (r.data ?? null) as AIWeeklyReview | null;
}
