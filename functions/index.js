const { sendScheduledNotification } = require('./notifications/sendNotifications');
const { clearDailyGoals } = require('./clearData/clearDailyGoals');
const { processGptRequest } = require('./utils/processGptRequests');
const { scheduledNewsCollection } = require('./newsFeed/newsCollection');
const { getUserNewsFeed } = require("./newsFeed/getUserNewsFeed");
const { getNewsSummary } = require("./newsFeed/getNewsSummary");

exports.sendScheduledNotification = sendScheduledNotification;
exports.clearDailyGoals = clearDailyGoals;
exports.processGptRequest = processGptRequest;
exports.scheduledNewsCollection = scheduledNewsCollection;
exports.getUserNewsFeed = getUserNewsFeed;
exports.getNewsSummary = getNewsSummary;