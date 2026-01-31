import { nano2date } from "./bigint";

const seconds = [];
const minutes = [];
for (let i = 0; i < 60; i++) {
	seconds.push(i + 1);
	minutes.push(i + 1);
}
const hours = [];
for (let i = 0; i < 24; i++) {
	hours.push(i + 1);
}
const days = [];
for (let i = 0; i < 30; i++) {
	days.push(i + 1);
}
const weeks = [];
for (let i = 0; i < 52; i++) {
  weeks.push(i + 1);
};

export const duration = {
	seconds,
	minutes,
	hours,
	days,
  weeks
}

export function duration2nano(val, unit) {
  const unitSecondsMap = {
    seconds: 1n,
    minutes: 60n,
    hours: 3600n,
    days: 86400n,
    weeks: 604800n,
  };
	const selected_secs = unitSecondsMap[unit] ?? 1n;
	const val_seconds = BigInt(val) * selected_secs;
	return val_seconds * 1000n * 1000000n; // to ms -> nano
}

// helper: inside the same module/class (above render or as a method)
export function timeLeft(expires_at) {
  if (!expires_at) return {
    expiresDisplay: '',
    leftLabel: 'Never expires'
  }

  const expires_at_date = nano2date(expires_at);
  const deltaMs = expires_at_date.getTime() - Date.now();

  if (deltaMs <= 0) {
    return {
      expiresDisplay: '',
      leftLabel: 'Expired',
    };
  }

  const secs = Math.ceil(deltaMs / 1000);
  if (secs < 60) {
    return {
      expiresDisplay: 'Expires: ' + expires_at_date.toLocaleTimeString(),
      leftLabel: `${secs} second${secs === 1 ? '' : 's'} left`,
    };
  }

  const mins = Math.ceil(deltaMs / (1000 * 60));
  if (mins < 60) {
    return {
      expiresDisplay: 'Expires: ' + expires_at_date.toLocaleTimeString(),
      leftLabel: `${mins} minute${mins === 1 ? '' : 's'} left`,
    };
  }

  const hours = Math.ceil(deltaMs / (1000 * 60 * 60));
  if (hours < 24) {
    return {
      expiresDisplay: 'Expires: ' + expires_at_date.toLocaleTimeString(),
      leftLabel: `${hours} hour${hours === 1 ? '' : 's'} left`,
    };
  }

  const days = Math.ceil(deltaMs / (1000 * 60 * 60 * 24));
  return {
    expiresDisplay: 'Expires: ' + expires_at_date.toLocaleDateString(),
    leftLabel: `${days} day${days === 1 ? '' : 's'} left`,
  };
}
