const admin = require('firebase-admin');
const { callOpenAI } = require("./openai");
const { onDocumentCreated } = require('firebase-functions/v2/firestore');

// Helper function to build GPT prompt with context and system prompt
async function buildPromptWithContext(userId, message, conversationId) {
  const db = admin.firestore();
  
  // Get conversation details
  const conversationDoc = await db.collection('Conversations').doc(conversationId).get();
  const conversationData = conversationDoc.data();
  const userFocus = conversationData?.userFocus || '';
  // const weeklyGoal = conversationData?.weeklyGoal || '';

  // Get conversation history (last 5 messages for context)
  const messagesSnapshot = await db
    .collection('Conversations')
    .doc(conversationId)
    .collection('Messages')
    .orderBy('timestamp', 'desc')
    .limit(5)           //  last 5 messages for context
    .get();

  const conversationHistory = messagesSnapshot.docs
    .map(doc => {
      const data = doc.data();
      return {
        role: data.role === 'user' ? 'user' : 'assistant',
        content: data.content
      };
    })
    .reverse();  // Reverse to get chronological order

  const systemPrompt = `
                        You are an expert productivity coach.
                        The user's current focus/goal is: ${userFocus}.
                        Provide actionable advice based on their focus and goals to help them stay on track.
                        Do not make any decisions if you are not at least 95% confident in the responses.
                        Ask clarifying questions to get that confidence.
                        This is the conversation history below:
                        `;

  const messages = [
    {
      role: 'system',
      content: systemPrompt
    }
  ];

  // Add conversation history if it exists (skip if this is the first user message)
  if (conversationHistory.length > 1) {
    // Only add history if there are messages other than the current one
    const historyWithoutCurrent = conversationHistory.slice(0, -1);
    messages.push(...historyWithoutCurrent);
  }

  console.log('Conversation gathered along with system prompt is:', messages);

  // Add the current user message
  messages.push({
    role: 'user',
    content: message
  });

  return messages;
}

// entry point to process GPT requests, Triggers when a new document is created in the GptRequests collection.
module.exports = {
  processGptRequest: onDocumentCreated(
    {
      document: 'GptRequests/{requestId}',
      secrets: ['OPENAI_API_KEY']
    },
    async (event) => {
      const snap = event.data;
      const requestData = snap.data();
      const { conversationId, content, userId } = requestData;

      const db = admin.firestore();
      // messages collection reference to add GPT response after processing
      const messagesRef = db.collection('Conversations')
        .doc(conversationId)
        .collection('Messages');

      let gptResponse;
      try {
        // return the conversation history for context + system prompt using the helper function: buildPromptWithContext
        const messages = await buildPromptWithContext(userId, content, conversationId);

        console.log(`Processing GPT request for user ${userId}, conversation ${conversationId}`);
        console.log(`Message count for context: ${messages.length}`);

        // Call API with the context attached
        const response = await callOpenAI({
          model: "gpt-3.5-turbo",
          messages: messages,
          temperature: 0.76,
          max_tokens: 420
        });

        gptResponse = response.data.choices[0].message.content;

        // Successfully save processed GPT response to /Messages collection in /Conversations
        await messagesRef.add({
          content: gptResponse,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          role: 'assistant',
          isFirstMessage: false,
          status: 'success'
        });

        // Update conversation's lastMessageAt
        await db.collection('Conversations').doc(conversationId).update({
          lastMessageAt: admin.firestore.FieldValue.serverTimestamp()
        });

        // Update request status in /GptRequests collection
        await snap.ref.update({ status: 'completed' });

      } catch (error) {
        console.error('GPT API Error:', error);

        // Saving error message
        await messagesRef.add({
          content: `Sorry, encountered an error: ${error}`,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          role: 'assistant',
          isFirstMessage: false,
          status: 'error',
          errorDetails: error.message
        });

        // Update request status
        await snap.ref.update({
          status: 'error',
          error: error.message
        });
      }
    }
  )
};