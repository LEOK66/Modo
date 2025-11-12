/**
 * Firebase Cloud Functions for Modo App
 * Handles AI chat requests through OpenAI API
 */

const {onCall} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");

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
 * - functions: Optional array of function definitions
 * - functionCall: Optional string
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

    // Add functions if provided
    if (data.functions &&
        Array.isArray(data.functions) &&
        data.functions.length > 0) {
      requestBody.functions = data.functions;
      if (data.functionCall) {
        requestBody.function_call = data.functionCall;
      }
    }

    logger.info("Calling OpenAI API", {
      model: requestBody.model,
      messageCount: requestBody.messages.length,
      hasFunctions: !!requestBody.functions,
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
