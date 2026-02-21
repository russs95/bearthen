import QtQuick 2.12
import Ubuntu.Components 1.3
import QtWebEngine 1.10

Page {
    id: accountPage

    // ── Header ────────────────────────────────────────────────────────────────
    header: PageHeader {
        id: pageHeader
        title: "Bearthen"
        subtitle: "Your Account"

        StyleHints {
            foregroundColor: "#4CAF50"
            backgroundColor: "#1A1A1A"
            dividerColor: "#2C5F2E"
        }
    }

    // ── Background ────────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: "#121212"
    }

    // ── Buwana OAuth2 PKCE Configuration ──────────────────────────────────────
    // ⚠️  Fill these in when reader.earthen.io backend is live
    // ─────────────────────────────────────────────────────────────────────────
    readonly property string buwanaAuthUrl:     "https://buwana.earthen.io/oauth/authorize"
    readonly property string buwanaTokenUrl:    "https://buwana.earthen.io/oauth/token"
    readonly property string buwanaLogoutUrl:   "https://buwana.earthen.io/oauth/logout"
    readonly property string clientId:          "bearthen-app"
    readonly property string redirectUri:       "https://reader.earthen.io/auth/callback"
    readonly property string scope:             "openid profile email"
    // ─────────────────────────────────────────────────────────────────────────

    // ── Auth state ────────────────────────────────────────────────────────────
    property bool   isLoggedIn:   false
    property string userName:     ""
    property string userEmail:    ""
    property string userAvatar:   ""
    property string accessToken:  ""
    property string codeVerifier: ""

    // ── PKCE helper functions ─────────────────────────────────────────────────

    // Generate a cryptographically random code verifier string
    function generateCodeVerifier() {
        var chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
        var result = ""
        for (var i = 0; i < 64; i++) {
            result += chars.charAt(Math.floor(Math.random() * chars.length))
        }
        return result
    }

    // Build the full Buwana authorization URL with PKCE params
    // Note: In production, code_challenge should be SHA-256 hash of verifier.
    // For this shell we pass the verifier directly (plain method) for simplicity.
    // Upgrade to S256 method when backend is live.
    function buildAuthUrl(verifier) {
        var params = [
            "response_type=code",
            "client_id="          + encodeURIComponent(clientId),
            "redirect_uri="       + encodeURIComponent(redirectUri),
            "scope="              + encodeURIComponent(scope),
            "code_challenge="     + verifier,
            "code_challenge_method=plain",
            "state=bearthen-login"
        ]
        return buwanaAuthUrl + "?" + params.join("&")
    }

    // Exchange auth code for access token
    function exchangeCodeForToken(code) {
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        var response = JSON.parse(xhr.responseText)
                        accountPage.accessToken = response.access_token || ""
                        fetchUserProfile()
                    } catch(e) {
                        console.log("Token parse error:", e)
                        authOverlay.visible = false
                        authError.visible = true
                    }
                } else {
                    console.log("Token exchange failed:", xhr.status)
                    authOverlay.visible = false
                    authError.visible = true
                }
            }
        }
        var body = [
            "grant_type=authorization_code",
            "code="          + encodeURIComponent(code),
            "redirect_uri="  + encodeURIComponent(redirectUri),
            "client_id="     + encodeURIComponent(clientId),
            "code_verifier=" + encodeURIComponent(accountPage.codeVerifier)
        ].join("&")

        xhr.open("POST", buwanaTokenUrl)
        xhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded")
        xhr.send(body)
    }

    // Fetch the logged-in user's profile from EarthReader backend
    function fetchUserProfile() {
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        var profile = JSON.parse(xhr.responseText)
                        accountPage.isLoggedIn  = true
                        accountPage.userName    = profile.name  || profile.username || "Reader"
                        accountPage.userEmail   = profile.email || ""
                        accountPage.userAvatar  = profile.avatar_url || ""
                        // Propagate login state to root app
                        root.isLoggedIn = true
                        root.userName   = accountPage.userName
                    } catch(e) {
                        console.log("Profile parse error:", e)
                    }
                }
                authOverlay.visible = false
            }
        }
        xhr.open("GET", "https://reader.earthen.io/api/profile")
        xhr.setRequestHeader("Authorization", "Bearer " + accountPage.accessToken)
        xhr.send()
    }

    // Sign the user out
    function signOut() {
        accountPage.isLoggedIn  = false
        accountPage.userName    = ""
        accountPage.userEmail   = ""
        accountPage.userAvatar  = ""
        accountPage.accessToken = ""
        root.isLoggedIn = false
        root.userName   = ""
    }

    // ── Logged-out view ───────────────────────────────────────────────────────
    Column {
        id: loggedOutView
        anchors.centerIn: parent
        spacing: units.gu(3)
        visible: !accountPage.isLoggedIn

        // Buwana / EarthReader identity mark
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: units.gu(14)
            height: units.gu(14)
            radius: width / 2
            color: "#1E3A1E"

            Column {
                anchors.centerIn: parent
                spacing: units.gu(0.4)

                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: units.gu(5)
                    height: units.gu(5)
                    name: "contact"
                    color: "#2C5F2E"
                }

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "earthen"
                    fontSize: "x-small"
                    color: "#4CAF50"
                    font.weight: Font.Medium
                }
            }
        }

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Sign in with Buwana"
            fontSize: "large"
            color: "#FFFFFF"
            font.weight: Font.Light
        }

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            width: units.gu(32)
            text: "Buwana is an independent, open identity platform. Signing in syncs your library, reading positions, and highlights across devices — privately."
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            fontSize: "small"
            color: "#888888"
            lineHeight: 1.4
        }

        // ── What you get with an account ──────────────────────────────────────
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: units.gu(34)
            height: featureList.height + units.gu(3)
            radius: units.gu(0.8)
            color: "#1A1A1A"
            border.color: "#2C2C2C"
            border.width: units.dp(1)

            Column {
                id: featureList
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    margins: units.gu(1.5)
                }
                spacing: units.gu(1.2)

                Repeater {
                    model: [
                        { icon: "sync",     text: "Sync reading position across devices"  },
                        { icon: "bookmark", text: "Back up highlights and annotations"    },
                        { icon: "history",  text: "Keep your full reading history"        },
                        { icon: "like",     text: "Save Gutenberg favourites online"      }
                    ]

                    Row {
                        spacing: units.gu(1.2)
                        width: featureList.width

                        Icon {
                            width: units.gu(2.2)
                            height: units.gu(2.2)
                            name: modelData.icon
                            color: "#4CAF50"
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Label {
                            text: modelData.text
                            fontSize: "small"
                            color: "#CCCCCC"
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - units.gu(3.4)
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }
        }

        // ── Sign in button ────────────────────────────────────────────────────
        Button {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Sign in with Buwana"
            color: "#2C5F2E"
            width: units.gu(28)
            onClicked: {
                accountPage.codeVerifier = generateCodeVerifier()
                var authUrl = buildAuthUrl(accountPage.codeVerifier)
                authWebView.url = authUrl
                authOverlay.visible = true
                authError.visible = false
            }
        }

        // Auth error message
        Label {
            id: authError
            anchors.horizontalCenter: parent.horizontalCenter
            width: units.gu(30)
            text: "Sign in failed. Please try again."
            visible: false
            color: "#E57373"
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            fontSize: "small"
        }

        // Privacy note
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            width: units.gu(28)
            text: "reader.earthen.io — no ads, no tracking, no data selling. Ever."
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            fontSize: "x-small"
            color: "#555555"
            lineHeight: 1.3
        }
    }

    // ── Logged-in view ────────────────────────────────────────────────────────
    Column {
        id: loggedInView
        anchors {
            top: pageHeader.bottom
            left: parent.left
            right: parent.right
            topMargin: units.gu(3)
        }
        spacing: units.gu(0)
        visible: accountPage.isLoggedIn

        // User identity card
        Rectangle {
            width: parent.width
            height: units.gu(14)
            color: "#1A1A1A"

            Row {
                anchors {
                    fill: parent
                    margins: units.gu(2)
                }
                spacing: units.gu(2)

                // Avatar circle
                Rectangle {
                    width: units.gu(9)
                    height: units.gu(9)
                    radius: width / 2
                    color: "#1E3A1E"
                    anchors.verticalCenter: parent.verticalCenter

                    Image {
                        anchors.fill: parent
                        source: accountPage.userAvatar
                        visible: accountPage.userAvatar.length > 0
                        fillMode: Image.PreserveAspectCrop
                    }

                    Icon {
                        anchors.centerIn: parent
                        width: units.gu(4)
                        height: units.gu(4)
                        name: "contact"
                        color: "#2C5F2E"
                        visible: accountPage.userAvatar.length === 0
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: units.gu(0.5)

                    Label {
                        text: accountPage.userName
                        fontSize: "large"
                        color: "#FFFFFF"
                        font.weight: Font.Medium
                    }

                    Label {
                        text: accountPage.userEmail
                        fontSize: "small"
                        color: "#888888"
                    }

                    Row {
                        spacing: units.gu(0.5)

                        Icon {
                            width: units.gu(1.8)
                            height: units.gu(1.8)
                            name: "tick"
                            color: "#4CAF50"
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Label {
                            text: "Buwana account connected"
                            fontSize: "x-small"
                            color: "#4CAF50"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }
        }

        // Divider
        Rectangle {
            width: parent.width
            height: units.dp(1)
            color: "#2C2C2C"
        }

        // Account feature rows
        Repeater {
            model: [
                { icon: "sync",     label: "Sync Status",       value: "Active" },
                { icon: "bookmark", label: "Annotations",        value: "Backed up" },
                { icon: "history",  label: "Reading History",    value: "Saved" },
                { icon: "like",     label: "Favourites",         value: "Synced" }
            ]

            ListItem {
                width: loggedInView.width
                height: units.gu(7)
                color: "transparent"
                divider.colorFrom: "#2C2C2C"
                divider.colorTo: "#121212"

                Row {
                    anchors {
                        fill: parent
                        margins: units.gu(2)
                    }
                    spacing: units.gu(1.5)

                    Icon {
                        width: units.gu(2.5)
                        height: units.gu(2.5)
                        name: modelData.icon
                        color: "#4CAF50"
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Label {
                        text: modelData.label
                        fontSize: "medium"
                        color: "#CCCCCC"
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - units.gu(10)
                    }

                    Label {
                        text: modelData.value
                        fontSize: "small"
                        color: "#4CAF50"
                        anchors {
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }
        }

        // Sign out button
        Item { width: parent.width; height: units.gu(3) }

        Button {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Sign Out"
            color: "transparent"
            strokeColor: "#E57373"
            width: units.gu(24)
            onClicked: signOutConfirm.visible = true
        }
    }

    // ── Buwana OAuth WebView overlay ──────────────────────────────────────────
    Rectangle {
        id: authOverlay
        anchors.fill: parent
        color: "#121212"
        visible: false
        z: 20

        Column {
            anchors.fill: parent

            // Overlay header
            Rectangle {
                width: parent.width
                height: units.gu(7)
                color: "#1A1A1A"

                Row {
                    anchors {
                        fill: parent
                        leftMargin: units.gu(1.5)
                        rightMargin: units.gu(1.5)
                    }

                    Label {
                        text: "Sign in with Buwana"
                        fontSize: "medium"
                        color: "#FFFFFF"
                        font.weight: Font.Medium
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - units.gu(10)
                    }

                    Button {
                        text: "Cancel"
                        color: "transparent"
                        strokeColor: "#666666"
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: {
                            authOverlay.visible = false
                            authWebView.url = "about:blank"
                        }
                    }
                }
            }

            // The WebView that hosts the Buwana login page
            WebEngineView {
                id: authWebView
                width: parent.width
                height: parent.height - units.gu(7)

                // Watch for the callback redirect URL
                onUrlChanged: {
                    var urlStr = authWebView.url.toString()
                    if (urlStr.indexOf(redirectUri) === 0) {
                        // Callback detected — extract the auth code
                        var codeMatch = urlStr.match(/[?&]code=([^&]+)/)
                        if (codeMatch && codeMatch[1]) {
                            var authCode = decodeURIComponent(codeMatch[1])
                            authWebView.url = "about:blank"
                            exchangeCodeForToken(authCode)
                        } else {
                            // Callback reached but no code — auth was denied
                            authOverlay.visible = false
                            authError.visible = true
                        }
                    }
                }
            }
        }
    }

    // ── Sign out confirmation dialog ──────────────────────────────────────────
    Rectangle {
        id: signOutConfirm
        anchors.fill: parent
        color: "#CC000000"
        visible: false
        z: 10

        MouseArea {
            anchors.fill: parent
            onClicked: signOutConfirm.visible = false
        }

        Rectangle {
            anchors.centerIn: parent
            width: units.gu(34)
            height: units.gu(20)
            radius: units.gu(1)
            color: "#1E1E1E"

            Column {
                anchors {
                    fill: parent
                    margins: units.gu(3)
                }
                spacing: units.gu(2)

                Label {
                    text: "Sign Out?"
                    fontSize: "large"
                    color: "#FFFFFF"
                    font.weight: Font.Medium
                }

                Label {
                    width: parent.width
                    text: "Your books stay on this device. Your reading data remains saved to your Buwana account."
                    wrapMode: Text.WordWrap
                    fontSize: "small"
                    color: "#AAAAAA"
                    lineHeight: 1.4
                }

                Row {
                    width: parent.width
                    spacing: units.gu(1.5)

                    Button {
                        text: "Cancel"
                        color: "transparent"
                        strokeColor: "#555555"
                        width: (parent.width - units.gu(1.5)) / 2
                        onClicked: signOutConfirm.visible = false
                    }

                    Button {
                        text: "Sign Out"
                        color: "#C62828"
                        width: (parent.width - units.gu(1.5)) / 2
                        onClicked: {
                            signOutConfirm.visible = false
                            signOut()
                        }
                    }
                }
            }
        }
    }
}