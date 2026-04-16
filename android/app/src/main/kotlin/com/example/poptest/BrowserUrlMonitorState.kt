package com.example.poptest

import java.util.Locale

object BrowserUrlMonitorState {
    private val lock = Any()

    private var targetPatterns: Set<String> = emptySet()
    private var latestPackageName: String? = null
    private var latestUrl: String? = null
    private var latestMatched = false

    fun updateTargets(customUrls: Set<String>) {
        synchronized(lock) {
            targetPatterns = customUrls
                .mapNotNull { normalizePattern(it) }
                .toSet()
            latestMatched = isUrlMatchedLocked(latestUrl)
        }
    }

    fun clear() {
        synchronized(lock) {
            targetPatterns = emptySet()
            latestPackageName = null
            latestUrl = null
            latestMatched = false
        }
    }

    fun updateBrowserUrl(packageName: String, url: String?) {
        synchronized(lock) {
            latestPackageName = packageName
            latestUrl = url
            latestMatched = isUrlMatchedLocked(url)
        }
    }

    fun isMatchedForForegroundPackage(foregroundPackage: String?): Boolean {
        if (foregroundPackage == null) return false
        synchronized(lock) {
            if (foregroundPackage != latestPackageName) return false
            return latestMatched
        }
    }

    fun latestUrlForForegroundPackage(foregroundPackage: String?): String? {
        if (foregroundPackage == null) return null
        synchronized(lock) {
            if (foregroundPackage != latestPackageName) return null
            return latestUrl
        }
    }

    private fun isUrlMatchedLocked(url: String?): Boolean {
        if (url.isNullOrBlank()) return false
        if (targetPatterns.isEmpty()) return false
        val normalizedUrl = normalizeUrl(url)
        val normalizedHost = extractHost(normalizedUrl)
        return targetPatterns.any { pattern ->
            val patternHost = extractHost(pattern)
            val hostMatched = hostMatches(normalizedHost, patternHost)
            if (!hostMatched) return@any false
            val hasPathConstraint = hasPathConstraint(pattern)
            if (!hasPathConstraint) return@any true
            if (!normalizedUrl.startsWith(pattern)) return@any false
            val nextChar = normalizedUrl.getOrNull(pattern.length) ?: return@any true
            nextChar == '/' || nextChar == '?' || nextChar == '#'
        }
    }

    private fun normalizePattern(value: String): String? {
        val trimmed = value.trim()
        if (trimmed.isEmpty()) return null
        return normalizeUrl(trimmed)
    }

    private fun normalizeUrl(value: String): String {
        var out = value.trim().lowercase(Locale.US)
        out = out.removePrefix("https://")
        out = out.removePrefix("http://")
        out = out.removePrefix("www.")
        return out.trimEnd('/')
    }

    private fun extractHost(value: String): String {
        return value.substringBefore('/').substringBefore('?').substringBefore('#')
    }

    private fun hostMatches(urlHost: String, patternHost: String): Boolean {
        if (urlHost.isBlank() || patternHost.isBlank()) return false
        return urlHost == patternHost || urlHost.endsWith(".$patternHost")
    }

    private fun hasPathConstraint(pattern: String): Boolean {
        val pathIndex = pattern.indexOf('/')
        if (pathIndex < 0) return false
        val queryIndex = pattern.indexOf('?').let { if (it >= 0) it else Int.MAX_VALUE }
        val fragmentIndex = pattern.indexOf('#').let { if (it >= 0) it else Int.MAX_VALUE }
        val firstSuffixIndex = minOf(queryIndex, fragmentIndex)
        return pathIndex < firstSuffixIndex
    }
}
