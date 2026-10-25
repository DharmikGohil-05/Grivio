// Reusable neumorphic UI primitives + inline SVG icons (no icon dependency).
import type { ButtonHTMLAttributes, InputHTMLAttributes, ReactNode, SelectHTMLAttributes, TextareaHTMLAttributes } from 'react';

/* ----------------------------- Icons ----------------------------- */
// 24×24 stroke icons drawn to match the mobile app's Material set closely.
type IconProps = { size?: number; className?: string };
const svg = (path: ReactNode, size = 22) => (
  <svg
    width={size}
    height={size}
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    strokeWidth="1.9"
    strokeLinecap="round"
    strokeLinejoin="round"
    aria-hidden="true"
  >
    {path}
  </svg>
);

export const IconHome = ({ size }: IconProps) =>
  svg(
    <>
      <path d="M3 10.5 12 3l9 7.5" />
      <path d="M5 9.5V21h14V9.5" />
      <path d="M10 21v-6h4v6" />
    </>,
    size,
  );

export const IconFlag = ({ size }: IconProps) =>
  svg(
    <>
      <path d="M5 21V4" />
      <path d="M5 4h11l-2.2 3.5L16 11H5" />
    </>,
    size,
  );

export const IconTimer = ({ size }: IconProps) =>
  svg(
    <>
      <circle cx="12" cy="13.5" r="7.5" />
      <path d="M12 9.5v4l2.5 2" />
      <path d="M9.5 2.5h5" />
    </>,
    size,
  );

export const IconChart = ({ size }: IconProps) =>
  svg(
    <>
      <path d="M4 20V10" />
      <path d="M10 20V4" />
      <path d="M16 20v-7" />
      <path d="M21 20H3" />
    </>,
    size,
  );

export const IconUser = ({ size }: IconProps) =>
  svg(
    <>
      <circle cx="12" cy="8" r="4" />
      <path d="M4.5 20c1.4-3.4 4.1-5 7.5-5s6.1 1.6 7.5 5" />
    </>,
    size,
  );

export const IconSun = ({ size }: IconProps) =>
  svg(
    <>
      <circle cx="12" cy="12" r="4.2" />
      <path d="M12 2.5v2M12 19.5v2M2.5 12h2M19.5 12h2M5 5l1.4 1.4M17.6 17.6 19 19M19 5l-1.4 1.4M6.4 17.6 5 19" />
    </>,
    size,
  );

export const IconMoon = ({ size }: IconProps) =>
  svg(<path d="M20 13.5A8 8 0 0 1 10.5 4 8 8 0 1 0 20 13.5Z" />, size);

export const IconPlus = ({ size }: IconProps) => svg(<path d="M12 5v14M5 12h14" />, size);
export const IconCheck = ({ size }: IconProps) => svg(<path d="M4.5 12.5 9.5 17.5 19.5 6.5" />, size);
export const IconClose = ({ size }: IconProps) => svg(<path d="M6 6l12 12M18 6 6 18" />, size);
export const IconSparkles = ({ size }: IconProps) =>
  svg(
    <>
      <path d="M12 3v4M12 17v4M3 12h4M17 12h4" />
      <path d="M12 8.5 13.2 11l2.5 1-2.5 1L12 15.5 10.8 13l-2.5-1 2.5-1Z" />
    </>,
    size,
  );
export const IconTrash = ({ size }: IconProps) =>
  svg(
    <>
      <path d="M4 7h16" />
      <path d="M9 7V4.5h6V7" />
      <path d="M6 7l1 13h10l1-13" />
    </>,
    size,
  );
export const IconLogout = ({ size }: IconProps) =>
  svg(
    <>
      <path d="M14 4h-8v16h8" />
      <path d="M10 12h10m0 0-3.5-3.5M20 12l-3.5 3.5" />
    </>,
    size,
  );
export const IconEdit = ({ size }: IconProps) =>
  svg(
    <>
      <path d="M4 20h4L19 9l-4-4L4 16Z" />
      <path d="m13.5 6.5 4 4" />
    </>,
    size,
  );

/* --------------------------- Primitives --------------------------- */

export function NeuCard({
  children,
  className = '',
  inset = false,
}: {
  children: ReactNode;
  className?: string;
  inset?: boolean;
}) {
  return <div className={`${inset ? 'neu-inset' : 'neu'} card ${className}`}>{children}</div>;
}

type BtnProps = ButtonHTMLAttributes<HTMLButtonElement> & {
  variant?: 'default' | 'primary' | 'ghost' | 'danger';
  size?: 'sm' | 'md';
};

export function Button({ variant = 'default', size = 'md', className = '', ...rest }: BtnProps) {
  const classes = [
    'btn',
    variant === 'primary' && 'btn-primary',
    variant === 'ghost' && 'btn-ghost',
    variant === 'danger' && 'btn-danger',
    size === 'sm' && 'btn-sm',
    className,
  ]
    .filter(Boolean)
    .join(' ');
  return <button type="button" className={classes} {...rest} />;
}

export function Field({
  label,
  hint,
  children,
}: {
  label: string;
  hint?: string;
  children: ReactNode;
}) {
  return (
    <div className="field">
      <label>{label}</label>
      {children}
      {hint ? <span className="small muted">{hint}</span> : null}
    </div>
  );
}

export function Input(props: InputHTMLAttributes<HTMLInputElement>) {
  return <input className="input" {...props} />;
}

export function Textarea(props: TextareaHTMLAttributes<HTMLTextAreaElement>) {
  return <textarea className="textarea" {...props} />;
}

export function Select(props: SelectHTMLAttributes<HTMLSelectElement>) {
  return <select className="select" {...props} />;
}

export function Checkbox({ checked, onChange, label }: { checked: boolean; onChange: () => void; label?: string }) {
  return (
    <button
      type="button"
      role="checkbox"
      aria-checked={checked}
      aria-label={label ?? 'toggle'}
      className={`checkbox ${checked ? 'checked' : ''}`}
      onClick={onChange}
    >
      <IconCheck size={14} />
    </button>
  );
}

export function Modal({
  title,
  onClose,
  children,
  wide = false,
}: {
  title: string;
  onClose: () => void;
  children: ReactNode;
  wide?: boolean;
}) {
  return (
    // Clicking the backdrop (or Esc) closes, mirroring the mobile sheets:
    // closing without confirming never mutates anything.
    <div
      className="modal-overlay"
      onClick={(e) => {
        if (e.target === e.currentTarget) onClose();
      }}
      onKeyDown={(e) => {
        if (e.key === 'Escape') onClose();
      }}
      role="presentation"
    >
      <div className={`modal ${wide ? 'modal-wide' : ''}`} role="dialog" aria-modal="true" aria-label={title}>
        <div className="card-title">
          <h2>{title}</h2>
          <Button variant="ghost" size="sm" onClick={onClose} aria-label="Close">
            <IconClose size={16} />
          </Button>
        </div>
        {children}
      </div>
    </div>
  );
}

export function EmptyState({
  icon,
  title,
  message,
  action,
}: {
  icon: ReactNode;
  title: string;
  message: string;
  action?: ReactNode;
}) {
  return (
    <div className="empty">
      <div className="icon">{icon}</div>
      <h3>{title}</h3>
      <p className="small">{message}</p>
      {action}
    </div>
  );
}

export function Skeleton({ height = 18, width = '100%' }: { height?: number; width?: number | string }) {
  return <div className="skeleton" style={{ height, width }} aria-hidden="true" />;
}

export function ErrorBanner({ message }: { message: string }) {
  return (
    <div className="banner banner-error" role="alert">
      {message}
    </div>
  );
}

export function ProgressBar({ value }: { value: number }) {
  const v = Math.max(0, Math.min(100, value));
  return (
    <div
      className="progress-track"
      role="progressbar"
      aria-valuenow={v}
      aria-valuemin={0}
      aria-valuemax={100}
    >
      <div className="progress-fill" style={{ width: `${v}%` }} />
    </div>
  );
}

export function PriorityBadge({ priority }: { priority: string }) {
  return <span className={`badge badge-${priority}`}>{priority}</span>;
}

export function ThemeToggle({
  resolved,
  onToggle,
}: {
  resolved: 'light' | 'dark';
  onToggle: () => void;
}) {
  return (
    <Button
      variant="ghost"
      className="btn-icon"
      onClick={onToggle}
      aria-label={resolved === 'dark' ? 'Switch to light theme' : 'Switch to dark theme'}
      title={resolved === 'dark' ? 'Light mode' : 'Dark mode'}
    >
      {resolved === 'dark' ? <IconSun size={18} /> : <IconMoon size={18} />}
    </Button>
  );
}
