const { DateTime } = require('luxon');

function getTimeContext(userData) {
    const userTimezone = userData.timezone || "America/Los_Angeles";
    const userTime = DateTime.now().setZone(userTimezone);

    return {
        currentTime: userTime.toLocaleString(DateTime.DATETIME_FULL),
        dayOfWeek: userTime.weekdayLong,
        currentHour: userTime.hour,
        timezone: userTimezone,
    };
}

module.exports = { getTimeContext };