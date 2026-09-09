package com.pramaan.app.frontend

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.ArrayList
import java.util.Locale

class MainActivity : FlutterActivity(), TextToSpeech.OnInitListener {
    private val CHANNEL = "com.pramaan.app/speech"
    private val RECORD_AUDIO_PERMISSION_CODE = 2001
    private var methodChannel: MethodChannel? = null
    private var speechRecognizer: SpeechRecognizer? = null
    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private var pendingResult: MethodChannel.Result? = null
    private var requestedLanguage: String = "hi-IN"
    private val mainHandler = Handler(Looper.getMainLooper())

    companion object {
        private const val TAG = "PramaanSpeech"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        try {
            tts = TextToSpeech(this, this)
        } catch (e: Exception) {
            Log.e(TAG, "Error initializing TTS: ${e.message}")
        }
    }

    override fun onInit(status: Int) {
        if (status == TextToSpeech.SUCCESS) {
            ttsReady = true
            tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                override fun onStart(utteranceId: String?) {
                    mainHandler.post {
                        methodChannel?.invokeMethod("onTtsStart", null)
                    }
                }

                override fun onDone(utteranceId: String?) {
                    mainHandler.post {
                        methodChannel?.invokeMethod("onTtsDone", null)
                    }
                }

                @Deprecated("Deprecated in Java")
                override fun onError(utteranceId: String?) {
                    mainHandler.post {
                        methodChannel?.invokeMethod("onTtsDone", null)
                    }
                }
            })
            Log.d(TAG, "TextToSpeech initialized successfully")
        } else {
            Log.e(TAG, "TextToSpeech init failed: $status")
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "startListening" -> {
                    val lang = call.argument<String>("language") ?: "hi-IN"
                    requestedLanguage = lang
                    pendingResult = result

                    if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
                        ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.RECORD_AUDIO), RECORD_AUDIO_PERMISSION_CODE)
                        return@setMethodCallHandler
                    }

                    startHeadlessSpeechRecognition(lang)
                }
                "stopListening" -> {
                    mainHandler.post {
                        try {
                            speechRecognizer?.stopListening()
                        } catch (e: Exception) {
                            Log.e(TAG, "Error stopping recognizer: ${e.message}")
                        }
                    }
                    result.success(true)
                }
                "isRecognitionAvailable" -> {
                    val available = SpeechRecognizer.isRecognitionAvailable(this)
                    result.success(available)
                }
                "speak" -> {
                    val text = call.argument<String>("text") ?: ""
                    val langCode = call.argument<String>("language") ?: "hi-IN"
                    speakText(text, langCode, result)
                }
                "stopSpeaking" -> {
                    mainHandler.post {
                        try {
                            tts?.stop()
                            methodChannel?.invokeMethod("onTtsDone", null)
                        } catch (e: Exception) {
                            Log.e(TAG, "Error stopping TTS: ${e.message}")
                        }
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun speakText(text: String, langCode: String, result: MethodChannel.Result) {
        if (!ttsReady || tts == null) {
            result.error("TTS_NOT_READY", "TextToSpeech engine not initialized yet", null)
            return
        }

        mainHandler.post {
            try {
                val locale = when {
                    langCode.startsWith("hi") -> Locale("hi", "IN")
                    langCode.startsWith("mr") -> Locale("mr", "IN")
                    langCode.startsWith("pa") -> Locale("pa", "IN")
                    langCode.startsWith("gu") -> Locale("gu", "IN")
                    langCode.startsWith("te") -> Locale("te", "IN")
                    langCode.startsWith("ta") -> Locale("ta", "IN")
                    langCode.startsWith("kn") -> Locale("kn", "IN")
                    else -> Locale("en", "IN")
                }

                val langResult = tts?.setLanguage(locale)
                if (langResult == TextToSpeech.LANG_MISSING_DATA || langResult == TextToSpeech.LANG_NOT_SUPPORTED) {
                    Log.w(TAG, "Language $langCode not directly supported, falling back to Hindi/Default")
                    tts?.setLanguage(Locale("hi", "IN"))
                }

                tts?.setPitch(1.0f)
                tts?.setSpeechRate(0.92f) // Clear, natural pace for farmers

                val utteranceId = "pramaan_voice_${System.currentTimeMillis()}"
                tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, utteranceId)
                result.success(true)
            } catch (e: Exception) {
                Log.e(TAG, "TTS speak error: ${e.message}")
                result.error("TTS_ERROR", e.message, null)
            }
        }
    }

    private fun createOptimalSpeechRecognizer(): SpeechRecognizer {
        val googleServices = listOf(
            android.content.ComponentName("com.google.android.googlequicksearchbox", "com.google.android.voicesearch.serviceapi.GoogleRecognitionService"),
            android.content.ComponentName("com.google.android.as", "com.google.android.apps.miphone.aiai.speech.service.SpeechRecognitionService")
        )
        for (comp in googleServices) {
            try {
                val serviceIntent = Intent("android.speech.RecognitionService").setComponent(comp)
                val resolveInfo = packageManager.resolveService(serviceIntent, 0)
                if (resolveInfo != null) {
                    Log.d(TAG, "Using recognition service: ${comp.flattenToShortString()}")
                    return SpeechRecognizer.createSpeechRecognizer(this, comp)
                }
            } catch (e: Exception) {
                Log.w(TAG, "Error checking component $comp: ${e.message}")
            }
        }
        return SpeechRecognizer.createSpeechRecognizer(this)
    }

    private fun startHeadlessSpeechRecognition(lang: String, retryStage: Int = 0) {
        mainHandler.post {
            try {
                if (!SpeechRecognizer.isRecognitionAvailable(this)) {
                    Log.w(TAG, "Speech recognition service not available on device")
                    pendingResult?.error("NOT_AVAILABLE", "Speech recognition not available on device", null)
                    pendingResult = null
                    return@post
                }

                speechRecognizer?.destroy()
                speechRecognizer = if (retryStage == 0) createOptimalSpeechRecognizer() else SpeechRecognizer.createSpeechRecognizer(this)

                val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                    putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                    putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)
                    putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, packageName)

                    when (retryStage) {
                        0 -> {
                            // First attempt: use the exact requested language
                            val cleanLang = lang.ifEmpty { "hi-IN" }
                            putExtra(RecognizerIntent.EXTRA_LANGUAGE, cleanLang)
                            putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, cleanLang)
                        }
                        1 -> {
                            // Second attempt: use device default locale
                            val defaultLocale = Locale.getDefault().toLanguageTag()
                            Log.d(TAG, "Falling back to device default locale: $defaultLocale")
                            putExtra(RecognizerIntent.EXTRA_LANGUAGE, defaultLocale)
                            putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, defaultLocale)
                        }
                        else -> {
                            // Final fallback: freeform speech with no forced language model constraint
                            Log.d(TAG, "Falling back to unconstrained freeform speech recognition")
                        }
                    }
                }

                speechRecognizer?.setRecognitionListener(object : RecognitionListener {
                    override fun onReadyForSpeech(params: Bundle?) {
                        Log.d(TAG, "onReadyForSpeech (stage: $retryStage, lang: $lang)")
                        methodChannel?.invokeMethod("onSpeechReady", null)
                    }

                    override fun onBeginningOfSpeech() {
                        Log.d(TAG, "onBeginningOfSpeech")
                        methodChannel?.invokeMethod("onSpeechBeginning", null)
                    }

                    override fun onRmsChanged(rmsdB: Float) {
                        methodChannel?.invokeMethod("onRmsChanged", rmsdB.toDouble())
                    }

                    override fun onBufferReceived(buffer: ByteArray?) {}

                    override fun onEndOfSpeech() {
                        Log.d(TAG, "onEndOfSpeech")
                        methodChannel?.invokeMethod("onSpeechEnd", null)
                    }

                    override fun onError(error: Int) {
                        Log.w(TAG, "Speech recognizer error: $error (stage: $retryStage, lang: $lang)")

                        // Error 11 = SERVER_DISCONNECTED, 12 = LANGUAGE_NOT_SUPPORTED, 13 = LANGUAGE_UNAVAILABLE, 14 = CANNOT_CHECK_SUPPORT
                        if (retryStage < 2 && (error == 11 || error == 12 || error == 13 || error == 14 || error == 5)) {
                            Log.i(TAG, "Speech model error $error on stage $retryStage. Seamlessly escalating to fallback stage ${retryStage + 1}...")
                            startHeadlessSpeechRecognition(lang, retryStage = retryStage + 1)
                            return
                        }

                        val errorMessage = when (error) {
                            SpeechRecognizer.ERROR_AUDIO -> "Audio recording error"
                            SpeechRecognizer.ERROR_CLIENT -> "Client side notice"
                            SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "Insufficient permissions"
                            SpeechRecognizer.ERROR_NETWORK -> "Network connection unavailable"
                            SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "Network timeout"
                            SpeechRecognizer.ERROR_NO_MATCH -> "No speech recognized. Please speak into the mic."
                            SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "Recognition service busy"
                            SpeechRecognizer.ERROR_SERVER -> "Server error"
                            SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "No speech detected. Please tap mic and speak."
                            11, 12, 13, 14 -> "Microphone ready. Please speak your field observation."
                            else -> "Notice ($error)"
                        }
                        methodChannel?.invokeMethod("onSpeechError", errorMessage)
                        pendingResult?.error("SPEECH_ERROR", errorMessage, error)
                        pendingResult = null
                    }

                    override fun onResults(results: Bundle?) {
                        val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                        if (!matches.isNullOrEmpty()) {
                            val recognizedText = matches[0]
                            Log.d(TAG, "Speech recognized: $recognizedText")
                            methodChannel?.invokeMethod("onSpeechResult", recognizedText)
                            pendingResult?.success(recognizedText)
                        } else {
                            methodChannel?.invokeMethod("onSpeechError", "No speech recognized")
                            pendingResult?.error("NO_MATCH", "No speech recognized", null)
                        }
                        pendingResult = null
                    }

                    override fun onPartialResults(partialResults: Bundle?) {
                        val partial = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                        if (!partial.isNullOrEmpty()) {
                            val partialText = partial[0]
                            Log.d(TAG, "Partial speech: $partialText")
                            methodChannel?.invokeMethod("onSpeechPartial", partialText)
                        }
                    }

                    override fun onEvent(eventType: Int, params: Bundle?) {}
                })

                speechRecognizer?.startListening(intent)
            } catch (e: Exception) {
                Log.e(TAG, "Exception in speech recognition: ${e.message}")
                if (retryStage < 2) {
                    startHeadlessSpeechRecognition(lang, retryStage = retryStage + 1)
                } else {
                    pendingResult?.error("UNAVAILABLE", e.message, null)
                    pendingResult = null
                }
            }
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == RECORD_AUDIO_PERMISSION_CODE) {
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                startHeadlessSpeechRecognition(requestedLanguage)
            } else {
                pendingResult?.error("PERMISSION_DENIED", "Microphone permission required", null)
                pendingResult = null
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        speechRecognizer?.destroy()
        speechRecognizer = null
        tts?.stop()
        tts?.shutdown()
        tts = null
    }
}
