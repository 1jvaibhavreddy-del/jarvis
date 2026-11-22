package com.jarvis.app;

import android.annotation.SuppressLint;
import android.app.Activity;
import android.os.Bundle;
import android.webkit.WebView;
import android.webkit.WebViewClient;

/**
 * Jarvis on a tablet/phone.
 *
 * Loads a self-contained chat UI (assets/jarvis-chat.html) that talks to the
 * OpenAI-compatible API exposed by `jarvis serve` running on the same device
 * (via Termux) or on a machine on the same Wi-Fi.
 *
 * No external dependencies — just a WebView, so it builds cleanly with the
 * Android SDK and nothing else.
 */
public class MainActivity extends Activity {

    @SuppressLint("SetJavaScriptEnabled")
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        WebView webView = new WebView(this);
        setContentView(webView);

        WebViewClient client = new WebViewClient();
        webView.setWebViewClient(client);

        // The chat UI needs JavaScript + local storage (for saved server/model).
        webView.getSettings().setJavaScriptEnabled(true);
        webView.getSettings().setDomStorageEnabled(true);
        webView.getSettings().setDatabaseEnabled(true);
        // Allow http:// to the local Jarvis server (it speaks plain HTTP).
        webView.getSettings().setAllowFileAccess(true);
        webView.getSettings().setAllowContentAccess(true);

        webView.loadUrl("file:///android_asset/jarvis-chat.html");
    }
}
