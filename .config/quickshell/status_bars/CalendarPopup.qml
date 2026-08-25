import QtQuick
import QtQuick.Layouts
import Quickshell

// Календарь по клику на часах: крупные дата и время, сетка месяца с подсветкой
// сегодняшнего дня и листанием. Клик мимо закрывает окно силами композитора
// (grabFocus), поэтому таймера автозакрытия по уходу курсора здесь нет —
// в отличие от остальных меню панели.
PopupWindow {
    id: calendarRoot

    property date currentDate: new Date()
    property color backgroundColor: "#100f0f"
    property color hoverColor: "#282726"
    property color textColor: "#cecdc3"
    property color mutedTextColor: "#878580"
    property color borderColor: "#575653"
    property color separatorColor: "#403e3c"
    property color accentColor: "#4385be"
    property color weekendColor: "#d14d41"
    property string fontFamily: "IosevkaTerm Nerd Font Propo"

    signal closeRequested()

    // Показываемый месяц. Листание меняет только его, currentDate всегда «сейчас».
    property int viewYear: currentDate.getFullYear()
    property int viewMonth: currentDate.getMonth()

    readonly property var ruLocale: Qt.locale("ru_RU")

    // Сегодняшняя дата разложена по компонентам: currentDate меняется раз в
    // секунду, а эти три числа — раз в сутки, поэтому ячейки не перестраиваются
    // на каждый тик часов.
    readonly property int todayDay: currentDate.getDate()
    readonly property int todayMonth: currentDate.getMonth()
    readonly property int todayYear: currentDate.getFullYear()

    readonly property int cellWidth: 32
    readonly property int cellHeight: 24

    function capitalize(value) {
        return value.length > 0 ? value.charAt(0).toUpperCase() + value.slice(1) : value
    }

    function monthTitle() {
        return capitalize(ruLocale.standaloneMonthName(viewMonth, Locale.LongFormat))
            + " " + viewYear
    }

    function showToday() {
        viewYear = currentDate.getFullYear()
        viewMonth = currentDate.getMonth()
    }

    function shiftMonth(delta) {
        const shifted = new Date(viewYear, viewMonth + delta, 1)
        viewYear = shifted.getFullYear()
        viewMonth = shifted.getMonth()
    }

    // Заголовки дней недели с понедельника: dayName() нумерует с воскресенья (0).
    readonly property var weekdayNames: {
        const names = []
        for (let i = 1; i <= 7; i++)
            names.push(capitalize(ruLocale.dayName(i % 7, Locale.ShortFormat)))
        return names
    }

    // Всегда 42 ячейки (6 строк), чтобы высота окна не прыгала при листании.
    readonly property var cells: {
        const offset = (new Date(viewYear, viewMonth, 1).getDay() + 6) % 7
        const result = []
        for (let i = 0; i < 42; i++) {
            const date = new Date(viewYear, viewMonth, 1 - offset + i)
            result.push({
                day: date.getDate(),
                month: date.getMonth(),
                year: date.getFullYear(),
                inMonth: date.getMonth() === viewMonth && date.getFullYear() === viewYear,
                weekend: (i % 7) >= 5
            })
        }
        return result
    }

    function handleKey(event) {
        switch (event.key) {
        case Qt.Key_Escape:
            calendarRoot.closeRequested()
            break
        case Qt.Key_Left:
            calendarRoot.shiftMonth(-1)
            break
        case Qt.Key_Right:
            calendarRoot.shiftMonth(1)
            break
        case Qt.Key_PageUp:
            calendarRoot.shiftMonth(-12)
            break
        case Qt.Key_PageDown:
            calendarRoot.shiftMonth(12)
            break
        case Qt.Key_Home:
            calendarRoot.showToday()
            break
        default:
            return
        }

        event.accepted = true
    }

    implicitWidth: frame.implicitWidth
    implicitHeight: frame.implicitHeight
    color: "transparent"
    // Захват отдаёт окну клавиатуру и заставляет композитор закрыть его по
    // клику мимо — на этом держится «липкое» поведение календаря.
    grabFocus: true

    onVisibleChanged: {
        if (visible) {
            showToday()
            frame.forceActiveFocus()
        }
    }

    Rectangle {
        id: frame

        anchors.fill: parent
        implicitWidth: content.implicitWidth + 24
        implicitHeight: content.implicitHeight + 16
        color: calendarRoot.backgroundColor
        border.width: 1
        border.color: calendarRoot.borderColor
        radius: 5
        focus: true

        Keys.onPressed: event => calendarRoot.handleKey(event)

        ColumnLayout {
            id: content

            anchors.fill: parent
            anchors.topMargin: 8
            anchors.bottomMargin: 8
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 0

            Text {
                Layout.fillWidth: true
                text: calendarRoot.capitalize(
                    calendarRoot.currentDate.toLocaleDateString(calendarRoot.ruLocale,
                                                                "dddd, d MMMM"))
                color: calendarRoot.mutedTextColor
                font.family: calendarRoot.fontFamily
                font.pixelSize: 13
                horizontalAlignment: Text.AlignHCenter
                renderType: Text.NativeRendering
            }

            Text {
                Layout.fillWidth: true
                Layout.topMargin: 1
                text: Qt.formatDateTime(calendarRoot.currentDate, "HH:mm:ss")
                color: calendarRoot.textColor
                font.family: calendarRoot.fontFamily
                font.pixelSize: 24
                font.weight: Font.Bold
                horizontalAlignment: Text.AlignHCenter
                renderType: Text.NativeRendering
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 8
                Layout.bottomMargin: 6
                implicitHeight: 1
                color: calendarRoot.separatorColor
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: 4
                spacing: 0

                CalendarButton {
                    text: "‹"
                    hoverColor: calendarRoot.hoverColor
                    textColor: calendarRoot.textColor
                    fontFamily: calendarRoot.fontFamily
                    onActivated: calendarRoot.shiftMonth(-1)
                }

                // Клик по названию месяца возвращает к текущему.
                CalendarButton {
                    Layout.fillWidth: true
                    text: calendarRoot.monthTitle()
                    pixelSize: 13
                    bold: true
                    hoverColor: calendarRoot.hoverColor
                    textColor: calendarRoot.textColor
                    fontFamily: calendarRoot.fontFamily
                    onActivated: calendarRoot.showToday()
                }

                CalendarButton {
                    text: "›"
                    hoverColor: calendarRoot.hoverColor
                    textColor: calendarRoot.textColor
                    fontFamily: calendarRoot.fontFamily
                    onActivated: calendarRoot.shiftMonth(1)
                }
            }

            Grid {
                Layout.alignment: Qt.AlignHCenter
                columns: 7
                spacing: 2

                Repeater {
                    model: calendarRoot.weekdayNames

                    delegate: Text {
                        required property string modelData

                        width: calendarRoot.cellWidth
                        height: 18
                        text: modelData
                        color: calendarRoot.mutedTextColor
                        font.family: calendarRoot.fontFamily
                        font.pixelSize: 11
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        renderType: Text.NativeRendering
                    }
                }
            }

            Item {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: grid.implicitWidth
                implicitHeight: grid.implicitHeight

                Grid {
                    id: grid

                    columns: 7
                    spacing: 2

                    Repeater {
                        model: calendarRoot.cells

                        delegate: CalendarDay {
                            required property var modelData

                            width: calendarRoot.cellWidth
                            height: calendarRoot.cellHeight
                            day: modelData.day
                            inMonth: modelData.inMonth
                            weekend: modelData.weekend
                            today: modelData.day === calendarRoot.todayDay
                                && modelData.month === calendarRoot.todayMonth
                                && modelData.year === calendarRoot.todayYear
                            backgroundColor: calendarRoot.backgroundColor
                            hoverColor: calendarRoot.hoverColor
                            textColor: calendarRoot.textColor
                            mutedTextColor: calendarRoot.mutedTextColor
                            accentColor: calendarRoot.accentColor
                            weekendColor: calendarRoot.weekendColor
                            fontFamily: calendarRoot.fontFamily
                        }
                    }
                }

                // Колесо над сеткой листает месяцы. WheelHandler, а не MouseArea:
                // он не перехватывает наведение у ячеек под ним.
                WheelHandler {
                    onWheel: event => calendarRoot.shiftMonth(event.angleDelta.y > 0 ? -1 : 1)
                }
            }
        }
    }
}
