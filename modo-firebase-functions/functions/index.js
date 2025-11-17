/**
 * Firebase Cloud Functions for Modo App
 * Handles AI chat requests through OpenAI API
 */

const {onCall} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

// Initialize Firebase Admin SDK
if (!admin.apps.length) {
  admin.initializeApp();
}

// OpenAI API Configuration
const OPENAI_API_URL = "https://api.openai.com/v1/chat/completions";

/**
 * Callable function to handle chat requests with OpenAI
 *
 * Expected request data:
 * - messages: Array of message objects with role and content
 * - model: String (default: "gpt-4o")
 * - temperature: Number (default: 0.9)
 * - maxTokens: Number (default: 1000)
 * - tools: Optional array of tool definitions (new format, supports strict)
 * - toolChoice: Optional string or object (replaces functionCall)
 * - parallelToolCalls: Optional boolean
 *
 * Returns:
 * - { success: true, data: ChatCompletionResponse }
 * - { success: false, error: string }
 *
 * Environment Variables:
 * - OPENAI_API_KEY: Your OpenAI API key (set as secret or env var)
 */
exports.chatWithAI = onCall(async (request) => {
  try {
    // Get OpenAI API key from environment variable
    const apiKey = process.env.OPENAI_API_KEY;

    if (!apiKey || apiKey === "") {
      logger.error("OPENAI_API_KEY is not set in environment variables");
      return {
        success: false,
        error: "OpenAI API key is not configured. " +
          "Please set OPENAI_API_KEY environment variable.",
      };
    }

    // Validate request data
    const data = request.data;
    if (!data || !data.messages || !Array.isArray(data.messages)) {
      return {
        success: false,
        error: "Invalid request: messages array is required",
      };
    }

    // Prepare OpenAI API request
    const requestBody = {
      model: data.model || "gpt-4o",
      messages: data.messages,
      temperature: data.temperature !== undefined ? data.temperature : 0.9,
      max_tokens: data.maxTokens !== undefined ? data.maxTokens : 1000,
    };

    // Add tools if provided (new format, supports strict parameter)
    if (data.tools &&
        Array.isArray(data.tools) &&
        data.tools.length > 0) {
      requestBody.tools = data.tools;
      if (data.toolChoice !== undefined) {
        requestBody.tool_choice = data.toolChoice;
      }
      if (data.parallelToolCalls !== undefined) {
        requestBody.parallel_tool_calls = data.parallelToolCalls;
      }
    }

    logger.info("Calling OpenAI API", {
      model: requestBody.model,
      messageCount: requestBody.messages.length,
      hasTools: !!requestBody.tools,
      toolChoice: data.toolChoice,
    });

    // Call OpenAI API
    const response = await fetch(OPENAI_API_URL, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(requestBody),
    });

    // Check if request was successful
    if (!response.ok) {
      const errorText = await response.text();
      logger.error("OpenAI API error", {
        status: response.status,
        statusText: response.statusText,
        error: errorText,
      });

      let errorMessage =
        `OpenAI API error: ${response.status} ${response.statusText}`;
      try {
        const errorJson = JSON.parse(errorText);
        if (errorJson.error && errorJson.error.message) {
          errorMessage = errorJson.error.message;
        }
      } catch (e) {
        // If parsing fails, use the error text as is
      }

      return {
        success: false,
        error: errorMessage,
      };
    }

    // Parse response
    const responseData = await response.json();

    logger.info("OpenAI API success", {
      model: responseData.model,
      choices: (responseData.choices && responseData.choices.length) || 0,
      usage: responseData.usage,
    });

    // Return success response
    return {
      success: true,
      data: responseData,
    };
  } catch (error) {
    logger.error("Error in chatWithAI", {
      error: error.message,
      stack: error.stack,
    });

    // Return error response
    return {
      success: false,
      error: error.message || "An unknown error occurred",
    };
  }
});

/**
 * Callable function to delete user account and all associated data
 *
 * Expected request data: None (uses authenticated user from request.auth)
 *
 * Returns:
 * - { success: true, message: string }
 * - { success: false, error: string }
 *
 * This function:
 * 1. Verifies the user is authenticated
 * 2. Deletes all user data from Realtime Database
 * 3. Deletes all user files from Storage
 * 4. Deletes the user account from Firebase Auth
 */
exports.deleteAccount = onCall(async (request) => {
  try {
    // Verify user is authenticated
    if (!request.auth) {
      return {
        success: false,
        error: "Unauthorized: User must be authenticated",
      };
    }

    const userId = request.auth.uid;
    logger.info("Deleting account for user", {userId});

    // 1. Delete user data from Realtime Database
    try {
      const userRef = admin.database().ref(`users/${userId}`);
      await userRef.remove();
      logger.info("Deleted user data from Realtime Database", {userId});
    } catch (error) {
      logger.error("Error deleting user data from Realtime Database", {
        userId,
        error: error.message,
      });
      // Continue with other deletions even if this fails
    }

    // 2. Delete user files from Storage
    try {
      const bucket = admin.storage().bucket();
      const userStoragePath = `users/${userId}`;

      // List all files in user's storage path
      const [files] = await bucket.getFiles({
        prefix: userStoragePath,
      });

      // Delete each file
      const deletePromises = files.map((file) => file.delete());
      await Promise.all(deletePromises);

      logger.info("Deleted user files from Storage", {
        userId,
        fileCount: files.length,
      });
    } catch (error) {
      logger.error("Error deleting user files from Storage", {
        userId,
        error: error.message,
      });
      // Continue with auth deletion even if this fails
    }

    // 3. Delete user account from Firebase Auth
    try {
      await admin.auth().deleteUser(userId);
      logger.info("Deleted user account from Firebase Auth", {userId});
    } catch (error) {
      logger.error("Error deleting user account from Firebase Auth", {
        userId,
        error: error.message,
      });
      return {
        success: false,
        error: `Failed to delete user account: ${error.message}`,
      };
    }

    logger.info("Successfully deleted account for user", {userId});

    return {
      success: true,
      message: "Account and all associated data have been deleted",
    };
  } catch (error) {
    logger.error("Error in deleteAccount", {
      error: error.message,
      stack: error.stack,
    });

    return {
      success: false,
      error: error.message || "An unknown error occurred",
    };
  }
});
