package com.example.poptest

import android.accessibilityservice.AccessibilityService
import android.content.ComponentName
import android.content.Context
import android.provider.Settings
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import java.util.Locale

class AccessibilityMonitorService : AccessibilityService() {
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        val packageName = event?.packageName?.toString() ?: return
        if (!browserPackages.contains(packageName)) return
        val root = rootInActiveWindow ?: return
        val url = findUrl(root, packageName)
        BrowserUrlMonitorState.updateBrowserUrl(packageName, url)
    }

    override fun onInterrupt() = Unit

    override fun onServiceConnected() {
        super.onServiceConnected()
        BrowserUrlMonitorState.clear()
    }

    companion object {
        private val browserPackages = setOf(
            "com.android.chrome",
            "com.brave.browser",
            "com.sec.android.app.sbrowser",
            "org.mozilla.firefox",
            "org.mozilla.focus",
            "com.microsoft.emmx",
            "com.opera.browser",
            "com.duckduckgo.mobile.android",
        )

        private val knownUrlBarIds = mapOf(
            "com.android.chrome" to listOf("com.android.chrome:id/url_bar"),
            "com.brave.browser" to listOf("com.brave.browser:id/url_bar"),
            "com.sec.android.app.sbrowser" to listOf("com.sec.android.app.sbrowser:id/location_bar_edit_text"),
            "org.mozilla.firefox" to listOf("org.mozilla.firefox:id/mozac_browser_toolbar_url_view"),
            "org.mozilla.focus" to listOf("org.mozilla.focus:id/mozac_browser_toolbar_url_view"),
            "com.microsoft.emmx" to listOf("com.microsoft.emmx:id/url_bar"),
            "com.opera.browser" to listOf("com.opera.browser:id/url_field"),
            "com.duckduckgo.mobile.android" to listOf("com.duckduckgo.mobile.android:id/omnibarTextInput"),
        )

        fun isAccessibilityEnabled(context: Context): Boolean {
            val expectedComponent = ComponentName(context, AccessibilityMonitorService::class.java)
            val enabledServices = Settings.Secure.getString(
                context.contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
            ) ?: return false
            val expected = expectedComponent.flattenToString()
            return enabledServices.split(':').any { it.equals(expected, ignoreCase = true) }
        }
    }

    private fun findUrl(root: AccessibilityNodeInfo, packageName: String): String? {
        val knownIds = knownUrlBarIds[packageName] ?: emptyList()
        for (viewId in knownIds) {
            val nodes = root.findAccessibilityNodeInfosByViewId(viewId)
            if (nodes.isNullOrEmpty()) continue
            val text = nodes.firstNotNullOfOrNull { node ->
                node.text?.toString()?.trim()?.takeIf { it.isNotEmpty() }
                    ?: node.contentDescription?.toString()?.trim()?.takeIf { it.isNotEmpty() }
            }
            if (!text.isNullOrBlank()) return text
        }
        return findLikelyUrlByTraversal(root)
    }

    private fun findLikelyUrlByTraversal(root: AccessibilityNodeInfo): String? {
        val queue = ArrayDeque<AccessibilityNodeInfo>()
        queue.add(root)
        while (queue.isNotEmpty()) {
            val node = queue.removeFirst()
            val text = node.text?.toString()?.trim()
                ?: node.contentDescription?.toString()?.trim()
            if (!text.isNullOrBlank() && looksLikeUrl(text)) {
                return text
            }
            for (i in 0 until node.childCount) {
                node.getChild(i)?.let(queue::addLast)
            }
        }
        return null
    }

    private fun looksLikeUrl(text: String): Boolean {
        val candidate = text.lowercase(Locale.US)
        return candidate.contains("://") || candidate.contains('.') || candidate.startsWith("about:")
    }
}
