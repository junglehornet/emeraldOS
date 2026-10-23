pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic

Rectangle {
    id: root
    width: 1920; height: 1080
    color: "#0e1512"
    property color ink: "#dce8e0"
    property color muted: "#83998b"
    property color accent: "#50d890"
    property bool busy: false
    property string powerAction: ""
    property date now: new Date()
    function login() {
        if (busy || !username.text.trim() || sessions.currentIndex < 0) return;
        message.text = "";
        busy = true;
        sddm.login(username.text.trim(), password.text, sessions.currentIndex);
    }
    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = new Date() }
    Connections {
        target: sddm
        function onLoginFailed() {
            root.busy = false; password.clear();
            message.text = "Sign-in failed. Please try again.";
            password.forceActiveFocus();
        }
        function onLoginSucceeded() { password.clear(); message.text = "Welcome back."; }
        function onInformationMessage(message) { statusText.text = message; }
    }
    Image { anchors.fill: parent; source: "background.png"; fillMode: Image.PreserveAspectCrop }
    component Label: Text { color: root.ink; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13 }
    component Action: Button {
        id: action
        property bool primary: false
        implicitHeight: 46
        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13
        hoverEnabled: true
        contentItem: Text {
            text: action.text; font: action.font
            color: action.primary ? "#0e1512" : root.ink
            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
            opacity: action.enabled ? 1 : 0.5
        }
        background: Rectangle {
            radius: 10
            color: action.primary ? (action.down ? "#38ad70" : action.hovered ? "#77f2ac" : root.accent) : (action.hovered ? "#243d2f" : "#18231d")
            border.color: action.activeFocus ? root.accent : "#304038"
            border.width: action.activeFocus ? 2 : 1
        }
    }
    component Field: TextField {
        implicitHeight: 50
        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14
        color: root.ink; placeholderTextColor: root.muted
        selectionColor: "#29523b"; selectedTextColor: "#effff4"
        leftPadding: 16; rightPadding: 16
        background: Rectangle {
            radius: 10; color: "#0e1512"
            border.color: parent.activeFocus ? root.accent : "#304038"
            border.width: parent.activeFocus ? 2 : 1
        }
        enabled: !root.busy
        onAccepted: root.login()
    }
    Item {
        id: composition
        anchors.centerIn: parent
        width: Math.min(parent.width - 64, 1240)
        height: Math.min(parent.height - 140, 640)
        property bool wide: width > 850
        Column {
            visible: composition.wide
            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
            spacing: 16
            Row {
                spacing: 10
                Rectangle { width: 8; height: 8; radius: 4; color: root.accent; anchors.verticalCenter: parent.verticalCenter }
                Label { text: "EMERALD / HYPRLAND"; color: root.accent; font.letterSpacing: 3 }
            }
            Label { text: Qt.formatTime(root.now, "HH:mm"); font.pixelSize: Math.min(112, composition.width / 10); font.letterSpacing: -6 }
            Label { text: Qt.formatDate(root.now, "dddd, dd MMMM"); color: root.muted; font.pixelSize: 16 }
            Rectangle { width: 64; height: 2; color: root.accent }
            Label { text: "A little space to focus."; color: root.muted; font.pixelSize: 14 }
        }
        Rectangle {
            id: panel
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: composition.wide ? 0 : (composition.width - width) / 2
            width: Math.min(420, composition.width)
            height: form.implicitHeight + 64
            radius: 20; color: "#ee111916"; border.color: "#304038"
            Rectangle { width: 40; height: 3; radius: 2; color: root.accent; x: 32; y: 0 }
            Column {
                id: form
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 32 }
                spacing: 14
                Label { text: "WELCOME BACK"; color: root.accent; font.pixelSize: 11; font.letterSpacing: 3 }
                Label { text: "Make yourself at home."; font.family: "Adwaita Sans"; font.pixelSize: 26; width: parent.width; wrapMode: Text.WordWrap }
                Label { text: "Sign in to your workspace"; color: root.muted; bottomPadding: 10 }
                Label { text: "USER"; color: root.muted; font.pixelSize: 10; font.letterSpacing: 2 }
                Field { id: username; width: parent.width; text: userModel.lastUser; placeholderText: "Username"; Accessible.name: "Username"; onTextChanged: password.clear() }
                Label { text: "PASSWORD"; color: root.muted; font.pixelSize: 10; font.letterSpacing: 2 }
                Field { id: password; width: parent.width; echoMode: TextInput.Password; placeholderText: "Password"; Accessible.name: "Password" }
                Label { visible: keyboard.capsLock; text: "Caps Lock is on"; color: "#dfc179"; font.pixelSize: 11 }
                Label { text: "SESSION"; color: root.muted; font.pixelSize: 10; font.letterSpacing: 2 }
                ComboBox {
                    id: sessions
                    width: parent.width; height: 46
                    model: sessionModel; textRole: "name"; currentIndex: sessionModel.lastIndex
                    enabled: !root.busy
                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12
                    palette { text: "#dce8e0"; buttonText: "#dce8e0"; window: "#111916"; base: "#111916"; highlight: "#29523b"; highlightedText: "#effff4" }
                    contentItem: Label { text: sessions.displayText; verticalAlignment: Text.AlignVCenter; leftPadding: 14; rightPadding: 32; elide: Text.ElideRight }
                    background: Rectangle { radius: 10; color: "#0e1512"; border.color: sessions.activeFocus ? root.accent : "#304038" }
                }
                Label { id: message; width: parent.width; visible: text.length > 0; wrapMode: Text.WordWrap; color: "#ef8888"; font.pixelSize: 12; Accessible.role: Accessible.AlertMessage }
                Label { id: statusText; width: parent.width; visible: text.length > 0; wrapMode: Text.WordWrap; color: root.muted; font.pixelSize: 12 }
                Action { width: parent.width; text: root.busy ? "Signing in…" : "Sign in  →"; primary: true; enabled: !root.busy && username.text.trim().length > 0 && sessions.currentIndex >= 0; onClicked: root.login() }
            }
        }
    }
    Row {
        anchors { left: parent.left; bottom: parent.bottom; margins: 32 }
        spacing: 8
        Label { text: "●"; color: root.accent }
        Label { text: sddm.hostName; color: root.muted }
    }
    Row {
        anchors { right: parent.right; bottom: parent.bottom; margins: 24 }
        spacing: 10
        Action { width: 104; text: "Restart"; visible: sddm.canReboot; onClicked: { root.powerAction = "restart"; confirmPower.open(); } }
        Action { width: 104; text: "Shut down"; visible: sddm.canPowerOff; onClicked: { root.powerAction = "shut down"; confirmPower.open(); } }
    }
    Popup {
        id: confirmPower
        anchors.centerIn: parent; width: Math.min(380, root.width - 32); padding: 24
        modal: true; focus: true; closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        background: Rectangle { radius: 16; color: "#111916"; border.color: "#50d890" }
        contentItem: Column {
            spacing: 20
            Label { text: "Really " + root.powerAction + "?"; font.pixelSize: 18 }
            Row {
                spacing: 12
                Action { width: 144; text: "Cancel"; onClicked: confirmPower.close() }
                Action { width: 144; text: "Confirm"; primary: true; onClicked: { confirmPower.close(); if (root.powerAction === "restart") sddm.reboot(); else sddm.powerOff(); } }
            }
        }
    }
    Component.onCompleted: {
        if (username.text.length) password.forceActiveFocus(); else username.forceActiveFocus();
    }
}
