// js/ui.js — Helper de UI, Toasts e Badges (100% sem emojis, Lucide Icons e SweetAlert2)

export function badgeStatus(status) {
  switch (status) {
    case 'CONFIRMADA':
      return `<span class="px-2 py-0.5 border border-emerald-500/40 bg-emerald-950/60 text-emerald-400 font-mono text-xs uppercase flex items-center gap-1">
                <i data-lucide="check-circle-2" class="w-3 h-3"></i> CONFIRMADA
              </span>`;
    case 'EM_USO':
      return `<span class="px-2 py-0.5 border border-red-500/40 bg-red-950/60 text-red-400 font-mono text-xs uppercase flex items-center gap-1 animate-pulse">
                <i data-lucide="scan-line" class="w-3 h-3"></i> EM USO
              </span>`;
    case 'NO_SHOW':
      return `<span class="px-2 py-0.5 border border-slate-700 bg-slate-900 text-slate-400 font-mono text-xs uppercase flex items-center gap-1">
                <i data-lucide="alert-triangle" class="w-3 h-3"></i> NO SHOW
              </span>`;
    case 'CANCELADA':
      return `<span class="px-2 py-0.5 border border-zinc-800 bg-zinc-900 text-zinc-500 font-mono text-xs uppercase flex items-center gap-1 line-through">
                <i data-lucide="x-circle" class="w-3 h-3"></i> CANCELADA
              </span>`;
    case 'PENDENTE':
    default:
      return `<span class="px-2 py-0.5 border border-amber-600/40 bg-amber-950/60 text-amber-400 font-mono text-xs uppercase flex items-center gap-1">
                <i data-lucide="clock" class="w-3 h-3"></i> PENDENTE
              </span>`;
  }
}

export function showToast(title, message, icon = 'success') {
  Swal.fire({
    title,
    text: message,
    icon,
    toast: true,
    position: 'bottom-end',
    showConfirmButton: false,
    timer: 4000,
    background: '#1b1b1d',
    color: '#e5e1e4',
    customClass: {
      popup: 'border border-outline-variant/30'
    }
  });
}

export function maskPhone(phone) {
  if (!phone) return '';
  const clean = phone.replace(/\D/g, '');
  if (clean.length < 4) return '(**) *****-****';
  const lastFour = clean.slice(-4);
  return `(**) *****-${lastFour}`;
}
