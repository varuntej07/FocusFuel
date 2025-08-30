const { sendScheduledNotification } = require('./notifications/sendNotifications');
const { clearDailyGoals } = require('./clearData/clearDailyGoals');
const { processGptRequest } = require('./gptCalls/processGptRequests');
const { scheduledNewsCollection } = require('./newsFeed/newsCollection');
const { getUserNewsFeed } = require("./newsFeed/getUserNewsFeed");
const { getNewsSummary } = require("./newsFeed/getNewsSummary");
const { generateTaskQuestions } = require("./gptCalls/generateTaskQuestions");
const { generateGreeting } = require("./gptCalls/generateGreeting");

exports.sendScheduledNotification = sendScheduledNotification;
exports.clearDailyGoals = clearDailyGoals;
exports.processGptRequest = processGptRequest;
exports.scheduledNewsCollection = scheduledNewsCollection;
exports.getUserNewsFeed = getUserNewsFeed;
exports.getNewsSummary = getNewsSummary;
exports.generateTaskQuestions = generateTaskQuestions;
exports.generateGreeting = generateGreeting;