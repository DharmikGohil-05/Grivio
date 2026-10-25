// Domain types for the web client.
//
// The API responds with snake_case column names for resource rows (e.g.
// due_date, goal_id) and camelCase for computed payloads (AI plans, weekly
// stats). Types here are camelCase; mapping happens once in api/endpoints.ts,
// mirroring the Flutter app's models field-for-field.

export interface User {
  id: string;
  name: string;
  email: string;
}

export interface Profile {
  name: string;
  profilePicture: string | null;
  shortDescription: string | null;
  growthAreas: string[];
  mainGoal: string | null;
  dailyAvailableTime: string | null;
  setupCompleted: boolean;
}

export type TaskStatus = 'pending' | 'in_progress' | 'completed' | 'cancelled';
export type Priority = 'low' | 'medium' | 'high';

export interface Task {
  id: string;
  title: string;
  description: string | null;
  dueDate: string | null; // 'YYYY-MM-DD'
  priority: Priority;
  estimatedMinutes: number | null;
  category: string | null;
  status: TaskStatus;
  goalId: string | null;
  milestoneId: string | null;
  goalName: string | null;
  milestoneTitle: string | null;
  subtaskCount: number;
  completedSubtasks: number;
}

export interface Subtask {
  id: string;
  taskId: string;
  title: string;
  isCompleted: boolean;
  position: number;
}

export type GoalStatus = 'active' | 'completed' | 'archived';

export interface Goal {
  id: string;
  name: string;
  description: string | null;
  whyItMatters: string | null;
  growthArea: string | null;
  targetDate: string | null;
  status: GoalStatus;
  progress: number; // 0..100, computed server-side
  milestoneCount: number;
  completedMilestones: number;
}

export type MilestoneStatus = 'pending' | 'in_progress' | 'completed';

export interface Milestone {
  id: string;
  goalId: string;
  title: string;
  description: string | null;
  position: number;
  status: MilestoneStatus;
}

// The backend's focus_sessions.status column only ever holds these values.
// NOTE: there is NO 'paused' status — pausing sets paused_at while the
// status stays 'active' (see backend/src/services/focus.service.js and the
// Flutter FocusSession model, which derives paused from pausedAt != null).
export type SessionStatus = 'active' | 'completed' | 'cancelled';

export interface FocusSession {
  id: string;
  taskId: string | null;
  taskTitle: string | null;
  startedAt: string; // ISO
  endedAt: string | null;
  durationSeconds: number | null;
  status: SessionStatus;
  pausedAt: string | null;
  totalPauseSeconds: number;
  productivityRating: string | null;
  reflection: string | null;
}

export interface TrendPoint {
  date: string;
  value: number;
}

export interface ProgressSummary {
  tasksCompleted: number;
  focusMinutes: number;
  completionRate: number;
  activeGoals: number;
}

export interface GoalProgressItem {
  id: string;
  name: string;
  progress: number;
  targetDate: string | null;
}

export interface ProgressData {
  range: string;
  summary: ProgressSummary;
  taskTrend: TrendPoint[];
  focusTrend: TrendPoint[];
  goalProgress: GoalProgressItem[];
  insights: string[];
}

export interface WeeklyStats {
  weekStart: string; // Monday, 'YYYY-MM-DD'
  weekEnd: string;
  tasksCompleted: number;
  focusMinutes: number;
  goalsProgressed: number;
  completionRate: number;
  tasksTotal: number;
}

export interface WeeklyReview {
  id: string;
  weekStart: string;
  weekEnd: string;
  summary: string | null;
  biggestWin: string | null;
  needsAttention: string | null;
  nextWeekFocus: string | null;
}

export interface Reflection {
  id: string;
  date: string;
  wentWell: string | null;
  wasDifficult: string | null;
  toImprove: string | null;
}

// ---- AI payloads (camelCase, preview-only — nothing is saved by generating) ----

export interface SubtaskSuggestion {
  title: string;
  description: string | null;
  estimatedMinutes: number | null;
}

export interface TaskImprovement {
  title: string | null;
  description: string | null;
  category: string | null;
  priority: string | null;
  estimatedMinutes: number | null;
  subtasks: string[];
}

export interface BreakdownTask {
  title: string;
  description: string | null;
  estimatedMinutes: number | null;
}

export interface BreakdownPhase {
  title: string;
  description: string | null;
  tasks: BreakdownTask[];
}

export interface BreakdownProposal {
  phases: BreakdownPhase[];
}

export interface PlanSlot {
  taskId: string;
  title: string;
  priority: Priority;
  start: string; // 'HH:MM'
  minutes: number;
  isFallbackEstimate: boolean;
}

export interface UnscheduledItem {
  taskId: string;
  title: string;
  priority: Priority;
  reason: string;
}

export interface PlanBreak {
  start: string;
  minutes: number;
}

// Task proposed by the AI when the user has no open tasks — a preview
// only; nothing exists until the user picks it and it's created through
// the normal POST /tasks endpoint.
export interface SuggestedTask {
  title: string;
  minutes: number;
  priority: Priority;
}

export interface DailyPlan {
  date: string;
  availableMinutes: number;
  startTime: string;
  endTime: string;
  breakMinutes: number;
  capacityMinutes: number;
  plannedMinutes: number;
  remainingMinutes: number;
  contextApplied: boolean;
  scheduled: PlanSlot[];
  unscheduled: UnscheduledItem[];
  breaks: PlanBreak[];
  warnings: string[];
  suggestedTasks: SuggestedTask[];
}

export interface AIWeeklyReview {
  weekStart: string;
  weekEnd: string;
  lowData: boolean;
  summary: WeeklyStats | null;
  wins: string[];
  progressHighlights: string[];
  patterns: string[];
  challenges: string[];
  nextWeekPriorities: string[];
  suggestedActions: string[];
  dataLimitations: string[];
}
