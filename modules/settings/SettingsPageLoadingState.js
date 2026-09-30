// Compositor-independent projection of the page the user requested.
// A Ready previous page does not satisfy a Loading pending page.
function shouldShow(loadEnabled, requestedIndex, pageCount, hasSource,
                    errorIndex, currentIndex, currentStatus,
                    pendingIndex, pendingStatus, readyStatus) {
    if (!loadEnabled || !hasSource || requestedIndex < 0
            || requestedIndex >= pageCount || requestedIndex === errorIndex)
        return false
    if (pendingIndex === requestedIndex)
        return pendingStatus !== readyStatus
    if (currentIndex === requestedIndex)
        return currentStatus !== readyStatus
    return true // requested index changed before _requestPage() ran
}
