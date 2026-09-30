// An invalid sample is neutral. Anti-flashbang can dim, never amplify.
function bounded(value, fallback, low, high) {
    var number = Number(value);
    return Number.isFinite(number) ? Math.max(low, Math.min(high, number)) : fallback;
}
function multiplier(lightness, settings) {
    var sample = Number(lightness);
    if (!Number.isFinite(sample) || sample < 0 || sample > 100) return 1;
    settings = settings || {};
    var threshold = bounded(settings.threshold, .30, 0, .95);
    var strength = bounded(settings.strength, .90, 0, 1);
    var floor = bounded(settings.minMultiplier, .12, .05, 1);
    var exposure = Math.max(0, Math.min(1, (sample / 100 - threshold) / (1 - threshold)));
    var response = exposure * exposure * (3 - 2 * exposure);
    return Math.max(floor, Math.min(1, 1 - strength * (1 - floor) * response));
}
