// A cached Settings page owns no Diagnostics lease after navigation or hiding.
// Wait until the requested page is actually current before acquiring one.
function shouldLease(loadEnabled, hostVisible, requestedIndex,
                     currentIndex, diagnosticsIndex) {
    return loadEnabled === true && hostVisible === true
        && diagnosticsIndex >= 0
        && requestedIndex === diagnosticsIndex
        && currentIndex === diagnosticsIndex
}
