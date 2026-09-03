package com.pocketflow.app.groq

import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MultipartBody
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.asRequestBody
import org.json.JSONObject
import java.io.File
import java.io.IOException
import java.util.concurrent.TimeUnit

class GroqTranscriber(
    private val client: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(120, TimeUnit.SECONDS)
        .writeTimeout(120, TimeUnit.SECONDS)
        .build(),
) {
    fun transcribe(
        apiKey: String,
        audioFile: File,
        language: String = "en",
        model: String = MODEL,
    ): String {
        require(apiKey.isNotBlank()) { "Groq API key is missing" }
        require(audioFile.exists() && audioFile.length() > 0L) { "Audio file is empty" }

        val body = MultipartBody.Builder()
            .setType(MultipartBody.FORM)
            .addFormDataPart(
                "file",
                audioFile.name,
                audioFile.asRequestBody("audio/wav".toMediaType()),
            )
            .addFormDataPart("model", model)
            .addFormDataPart("language", language)
            .addFormDataPart("response_format", "json")
            .addFormDataPart(
                "prompt",
                "Dictation for computer control. Prefer clear punctuation.",
            )
            .build()

        val request = Request.Builder()
            .url(TRANSCRIPTIONS_URL)
            .header("Authorization", "Bearer $apiKey")
            .post(body)
            .build()

        client.newCall(request).execute().use { response ->
            val raw = response.body?.string().orEmpty()
            if (!response.isSuccessful) {
                throw IOException("Groq HTTP ${response.code}: $raw")
            }
            val text = JSONObject(raw).optString("text").trim()
            if (text.isEmpty()) {
                throw IOException("Groq returned empty transcript")
            }
            return text
        }
    }

    companion object {
        const val TRANSCRIPTIONS_URL = "https://api.groq.com/openai/v1/audio/transcriptions"
        const val MODEL = "whisper-large-v3-turbo"
    }
}
