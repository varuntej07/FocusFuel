const {admin, db} = require('../utils/firebase');
const { callOpenAI } = require("../utils/openai");
const { onDocumentCreated } = require('firebase-functions/v2/firestore');

// Helper function to extract clean text content from messages
function extractMessageContent(content) {
    // If content is already a string, return it
    if (typeof content === 'string') {
        return content;
    }

    // If it's an object (like from error messages), extract the actual content
    if (content && typeof content === 'object') {
        // Handle the notification object structure
        if (content.content) {
            return content.content;
        }
        // Handle error object structure
        if (content.message) {
            return content.message;
        }
    }

    // Fallback to string conversion
    return String(content || '');
}

// Helper function to build GPT prompt with context and system prompt
async function buildPromptWithContext(userId, message, conversationId) {
  
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

  // Build conversation history, filtering out error messages
  const conversationHistory = messagesSnapshot.docs
    .map(doc => {
      const data = doc.data();
      const content = extractMessageContent(data.content);
      return {
        role: data.role === 'user' ? 'user' : 'assistant',
        content: content
      };
    })
    .filter(msg => msg !== null)  // Remove null entries
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

  // Add conversation history if it exists (excluding the current message)
  const historyWithoutCurrent = conversationHistory.filter(msg =>
      msg.content !== message
  );

  if (historyWithoutCurrent.length > 0) {
       messages.push(...historyWithoutCurrent);
  }

  // Add the current user message
  messages.push({
    role: 'user',
    content: message
  });

  console.log(`Built prompt with ${messages.length} messages`);

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
      // Track if we've already created a response for this request
      const requestId = event.params.requestId;

      try {
      // Check if this request has already been processed
      const existingResponse = await messagesRef
          .where('requestId', '==', requestId)
          .where('role', '==', 'assistant')
          .limit(1)
          .get();

      if (!existingResponse.empty) {
          console.log(`Request ${requestId} already processed, skipping`);
          await snap.ref.update({ status: 'duplicate' });
          return;
      }
        // return the conversation history for context + system prompt using the helper function: buildPromptWithContext
        const messages = await buildPromptWithContext(userId, content, conversationId);

        console.log(`Processing GPT request for user ${userId}, conversation ${conversationId}`);
        console.log(`Message count for context processing is: ${messages.length}`);

        // Call API with the context attached
        const response = await callOpenAI({
          model: "gpt-4o-mini",
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
          status: 'success',
          requestId: requestId  // Track which request created this response
        });

        // Update conversation's lastMessageAt
        await db.collection('Conversations').doc(conversationId).update({
          lastMessageAt: admin.firestore.FieldValue.serverTimestamp()
        });

        // Update request status in /GptRequests collection
        await snap.ref.update({ status: 'completed' });

      } catch (error) {
        console.error(`Error processing request ${requestId}:`, error);

        // Create an error message in the conversation
        const errorMessage = await messagesRef.add({
            content: "I apologize, but I encountered an error processing your message. Please try again.",
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            role: 'assistant',
            isFirstMessage: false,
            status: 'error',
            errorDetails: error.message,
            requestId: requestId  // Track which request created this error
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