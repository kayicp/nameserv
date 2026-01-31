export function nano2date(ns) {
	if (!ns) return null;
	const ms = Number(ns / 1000000n);
	return new Date(ms);
}

export function date2nano() {
	const time = BigInt(new Date().getTime()) * 1000000n
	return time;
}