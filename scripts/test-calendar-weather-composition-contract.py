#!/usr/bin/env python3
"""Regression contract for Clock Calendar / Weather ownership."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WEATHER_CONTENT = ROOT / "modules/bar/weather/WeatherPopupContent.qml"
WEATHER_POPUP = ROOT / "modules/bar/weather/WeatherPopup.qml"
CLOCK = ROOT / "modules/bar/ClockWidget.qml"
CALENDAR_POPUP = ROOT / "modules/bar/ClockCalendarPopup.qml"
CALENDAR_CONTENT = ROOT / "modules/bar/ClockCalendarContent.qml"
SHARED_MONTH = ROOT / "modules/common/widgets/ObsidianMonthCalendar.qml"
SIDEBAR_CALENDAR = ROOT / "modules/sidebarRight/calendar/CalendarWidget.qml"
CLOCK_TOOLTIP = ROOT / "modules/bar/ClockWidgetTooltip.qml"
VERTICAL = ROOT / "modules/verticalBar/VerticalBarContent.qml"

def require(text: str, token: str, source: str) -> None:
    if token not in text:
        raise AssertionError(f"{source} is missing Clock Calendar / Weather contract token: {token!r}")

def forbid(text: str, token: str, source: str) -> None:
    if token in text:
        raise AssertionError(f"{source} contains retired Clock Calendar / Weather token: {token!r}")

def main() -> None:
    weather = WEATHER_CONTENT.read_text(encoding="utf-8")
    weather_popup = WEATHER_POPUP.read_text(encoding="utf-8")
    clock = CLOCK.read_text(encoding="utf-8")
    calendar_popup = CALENDAR_POPUP.read_text(encoding="utf-8")
    calendar = CALENDAR_CONTENT.read_text(encoding="utf-8")
    shared_month = SHARED_MONTH.read_text(encoding="utf-8")
    sidebar_calendar = SIDEBAR_CALENDAR.read_text(encoding="utf-8")
    vertical = VERTICAL.read_text(encoding="utf-8")

    if CLOCK_TOOLTIP.exists():
        raise AssertionError("retired ClockWidgetTooltip.qml must not return")

    for token in ("id: clockHoverArea", "ClockCalendarPopup {", "hoverTarget: clockHoverArea"):
        require(clock, token, "ClockWidget.qml")
    require(calendar_popup, "StyledPopup {", "ClockCalendarPopup.qml")
    require(calendar_popup, "ClockCalendarContent {", "ClockCalendarPopup.qml")
    forbid(calendar_popup, "PopupWindow", "ClockCalendarPopup.qml")

    for token in (
        "property int monthShift: 0",
        "for (let i = 0; i < 42; ++i)",
        "ObsidianMonthCalendar {",
        "anchors.horizontalCenter: parent.horizontalCenter",
    ):
        require(calendar, token, "ClockCalendarContent.qml")

    for token in (
        "import qs.services",
        "id: calendarHeader",
        "Layout.preferredWidth: calendarGrid.implicitWidth",
        "id: mondayMeasure",
        "x: Math.max(0, (root.cellSize - mondayMeasure.implicitWidth) / 2)",
        "property bool responsive: false",
        "property real responsiveMaxCellSize: 42",
        'root.locale.toString(root.viewingDate, "MMM")',
        'root.locale.toString(root.viewingDate, "yyyy")',
        'Translation.tr("Today").toUpperCase()',
        "readonly property bool currentMonth:",
        "opacity: 1",
        "color: todayButton.currentMonth ? root.colMuted : root.colAccent",
        'iconName: "chevron_left"',
        'iconName: "chevron_right"',
        "opacity: dayCell.modelData?.currentMonth === false ? 0.25 : 1",
    ):
        require(shared_month, token, "ObsidianMonthCalendar.qml")

    for token in (
        "ObsidianMonthCalendar {",
        "calendarCells: root.monthCells",
        "Layout.fillWidth: true",
        "responsive: true",
        "responsiveMaxCellSize: 42",
        "interactiveDays: true",
        "showEventDots: true",
        "CalendarLayout.getCalendarLayout(viewingDate, monthShift === 0, 1)",
    ):
        require(sidebar_calendar, token, "Sidebar CalendarWidget.qml")

    forbid(shared_month,
           "todayButton.opacity < 1 ? root.colMuted : root.colAccent",
           "ObsidianMonthCalendar.qml")

    for token in (
        "CalendarDayButton {",
        "id: todayCol",
        'locale.toString(viewingDate, "MMMM")',
    ):
        forbid(sidebar_calendar, token, "Sidebar CalendarWidget.qml")

    for token in ("StyledPopup {", "id: weatherContent", "root.presentationWindow?.width"):
        require(weather_popup, token, "WeatherPopup.qml")
    for token in (
        "readonly property real compactBreakpoint: 900",
        "readonly property int tabCount: 2",
        "property int currentTab: 0",
        "id: tabIndicator",
        "anchors.right: parent.right",
        "Behavior on y",
        "WheelHandler {",
        "id: timeWeatherPanel",
        "id: orbitalTimeline",
        "(Weather.data?.hourly ?? []).slice(0, 8)",
        "id: detailPanel",
    ):
        require(weather, token, "WeatherPopupContent.qml")
    for token in ("id: calendarPanel", "function calendarDay(index)", "columns: root.compact ? 1 : 2", "columns: root.compact ? 1 : 3"):
        forbid(weather, token, "WeatherPopupContent.qml")

    for token in ("component VerticalClockModule: Item", "Bar.ClockCalendarPopup {", "hoverTarget: clockHoverArea"):
        require(vertical, token, "VerticalBarContent.qml")

    print("Clock Calendar / Weather ownership contract: PASS")

if __name__ == "__main__":
    main()
