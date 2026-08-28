import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.Ui
import qs.Commons

// Spotify-only bar widget. The bar shows one glyph that dims while Spotify is
// closed, sits at the normal bar foreground while it is paused, and switches to
// the accent color while it is playing. Left click opens a garak-style flyout
// with album art, track info, a seek bar, and transport controls.
BarWidget {
  id: root
  moduleName: "byj.spotify"

  // ------------------------------------------------------------- settings
  readonly property string launchCommand: String(setting("launchCommand", "omarchy-launch-spotify"))
  readonly property string accentSetting: String(setting("accentColor", "theme"))
  readonly property int panelWidth: Number(setting("panelWidth", 340))
  readonly property int albumArtSize: Number(setting("albumArtSize", 84))
  readonly property bool hideWhenClosed: setting("hideWhenClosed", false) === true

  // "theme" (default) tracks Color.accent so the widget follows theme switches;
  // "spotify" pins the brand green; anything else is read as a #RRGGBB hex.
  readonly property color accentColor: {
    var token = accentSetting.trim().toLowerCase()
    if (token === "" || token === "theme") return Color.accent
    if (token === "spotify") return "#1DB954"
    return Style.colorFromHex(accentSetting, Color.accent)
  }

  // ------------------------------------------------------------- player
  readonly property var players: Mpris.players ? Mpris.players.values : []
  readonly property var player: pickSpotify(players)

  // Spotify desktop exports org.mpris.MediaPlayer2.spotify; spotifyd and
  // spotify-player share the prefix, and both are still Spotify.
  function isSpotify(p) {
    if (!p) return false
    if (String(p.dbusName || "").toLowerCase().indexOf("org.mpris.mediaplayer2.spotify") === 0) return true
    if (String(p.desktopEntry || "").toLowerCase() === "spotify") return true
    return String(p.identity || "").toLowerCase() === "spotify"
  }

  function pickSpotify(list) {
    var fallback = null
    for (var i = 0; i < list.length; i++) {
      var p = list[i]
      if (!isSpotify(p)) continue
      if (p.isPlaying) return p
      if (!fallback) fallback = p
    }
    return fallback
  }

  readonly property bool running: player !== null
  readonly property bool playing: running && player.isPlaying
  readonly property string title: running && player.trackTitle ? player.trackTitle : ""
  readonly property string artist: running && player.trackArtist ? player.trackArtist : ""
  readonly property string album: running && player.trackAlbum ? player.trackAlbum : ""
  readonly property string artUrl: running && player.trackArtUrl ? player.trackArtUrl : ""
  readonly property real trackLength: running && player.lengthSupported ? Math.max(0, player.length) : 0
  readonly property real trackPosition: running && player.positionSupported ? Math.max(0, player.position) : 0
  readonly property bool canSeek: running && player.canSeek && player.positionSupported && trackLength > 0

  property bool popupOpen: false

  // PopupCard's focus grab and the bar's one-popup-at-a-time coordinator both
  // dismiss through owner.close().
  function close() { popupOpen = false }

  // Broadcast targets: one bar surface exists per monitor and IPC only reaches
  // the instance that owns the target, so every method routed over IPC has to
  // be callable by name on each peer.
  function togglePopup() { popupOpen = running && !popupOpen }
  function openPopup() { popupOpen = running }
  function closePopup() { popupOpen = false }

  onRunningChanged: if (!running) popupOpen = false

  visible: hideWhenClosed ? running : true
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  // ------------------------------------------------------------- actions
  function playPause() {
    if (!running) return
    if (player.canTogglePlaying) player.togglePlaying()
    else if (player.isPlaying && player.canPause) player.pause()
    else if (!player.isPlaying && player.canPlay) player.play()
  }

  function nextTrack() { if (running && player.canGoNext) player.next() }
  function previousTrack() { if (running && player.canGoPrevious) player.previous() }
  function launch() { if (bar) bar.run(launchCommand) }

  function formatTime(seconds) {
    var total = Math.max(0, Math.floor(Number(seconds) || 0))
    var s = total % 60
    var m = Math.floor(total / 60) % 60
    var h = Math.floor(total / 3600)
    var pad = function (n) { return n < 10 ? "0" + n : String(n) }
    return h > 0 ? h + ":" + pad(m) + ":" + pad(s) : m + ":" + pad(s)
  }

  // MPRIS only pushes position on seek, so the elapsed time has to be pulled.
  // Only worth doing while the panel is actually on screen.
  Timer {
    running: root.popupOpen && root.playing && root.canSeek
    interval: 500
    repeat: true
    onTriggered: if (root.player) root.player.positionChanged()
  }

  IpcHandler {
    target: "byj.spotify"

    function toggle(): string {
      root.broadcast("togglePopup")
      return root.running ? "ok" : "not running"
    }

    function open(): string {
      root.broadcast("openPopup")
      return root.running ? "ok" : "not running"
    }

    function close(): string {
      root.broadcast("closePopup")
      return "ok"
    }

    function playPause(): string {
      root.playPause()
      return root.running ? "ok" : "not running"
    }

    function next(): string {
      root.nextTrack()
      return root.running ? "ok" : "not running"
    }

    function previous(): string {
      root.previousTrack()
      return root.running ? "ok" : "not running"
    }

    function launch(): string {
      root.launch()
      return "ok"
    }

    function status(): string {
      return JSON.stringify({
        running: root.running,
        playing: root.playing,
        title: root.title,
        artist: root.artist,
        album: root.album,
        artUrl: root.artUrl,
        position: root.trackPosition,
        length: root.trackLength,
        canSeek: root.canSeek
      })
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    active: root.playing
    activeColor: root.accentColor
    dimmed: !root.running
    tooltipText: root.running
      ? (root.title ? root.title + (root.artist ? " — " + root.artist : "") : "Spotify")
      : "Spotify — not running"

    onPressed: function (mouseButton) {
      if (mouseButton === Qt.MiddleButton) { root.launch(); return }
      if (!root.running) { root.launch(); return }
      if (mouseButton === Qt.RightButton) { root.playPause(); return }
      root.popupOpen = !root.popupOpen
    }

    onWheelMoved: function (delta) {
      if (!root.running) return
      if (delta > 0) root.previousTrack()
      else root.nextTrack()
    }
  }

  PopupCard {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(root.panelWidth))
    contentHeight: popup.fittedContentHeight(column.implicitHeight)

    Column {
      id: column
      anchors.fill: parent
      spacing: Style.space(12)

      Row {
        id: header
        width: parent.width
        spacing: Style.space(14)

        BorderSurface {
          id: artFrame
          width: Style.space(root.albumArtSize)
          height: width
          radius: Style.spacing.labelGap
          color: Style.normalFillFor(root.bar.foreground, Color.accent)
          borderSpec: Border.controlSpec("normal", root.bar.foreground, Color.accent)

          // Rounded album art: a hidden rounded rect drives a MultiEffect mask,
          // because Item.clip does not follow a radius.
          Rectangle {
            id: artMask
            anchors.fill: parent
            anchors.margins: artFrame.borderTop
            visible: false
            layer.enabled: true
            radius: Math.max(0, artFrame.radius - artFrame.borderTop)
            color: "white"
          }

          Item {
            anchors.fill: parent
            anchors.margins: artFrame.borderTop
            visible: root.artUrl !== ""
            layer.enabled: true
            layer.smooth: true
            layer.effect: MultiEffect {
              maskEnabled: true
              maskSource: artMask
              maskThresholdMin: 0.5
              maskSpreadAtMin: 0.3
            }

            Image {
              anchors.fill: parent
              source: root.artUrl
              fillMode: Image.PreserveAspectCrop
              asynchronous: true
              cache: true
              smooth: true
              sourceSize.width: artFrame.width * 2
              sourceSize.height: artFrame.height * 2
            }
          }

          Text {
            anchors.centerIn: parent
            visible: root.artUrl === ""
            text: ""
            color: Qt.darker(root.bar.foreground, 1.5)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.displayLarge
          }

          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.launch()
          }
        }

        Column {
          width: header.width - artFrame.width - header.spacing
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(4)

          Text {
            width: parent.width
            text: root.title || "Nothing playing"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.subtitle
            font.bold: true
            elide: Text.ElideRight
          }

          Text {
            width: parent.width
            text: root.artist
            color: Qt.darker(root.bar.foreground, 1.3)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
            visible: text !== ""
          }

          Text {
            width: parent.width
            text: root.album
            color: Qt.darker(root.bar.foreground, 1.6)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
            visible: text !== ""
          }
        }
      }

      Column {
        width: parent.width
        spacing: Style.space(2)
        visible: root.trackLength > 0

        PanelSlider {
          id: seek
          width: parent.width
          bar: root.bar
          minimum: 0
          maximum: Math.max(1, root.trackLength)
          value: Math.min(root.trackPosition, root.trackLength)
          step: 5
          fillColor: root.accentColor
          knobColor: root.accentColor
          enabled: root.canSeek
          opacity: root.canSeek ? 1 : 0.45
          onReleased: function (target) { if (root.canSeek) root.player.position = target }
        }

        Item {
          width: parent.width
          height: elapsedLabel.implicitHeight

          Text {
            id: elapsedLabel
            anchors.left: parent.left
            text: root.formatTime(seek.dragging ? seek.liveValue : root.trackPosition)
            color: Qt.darker(root.bar.foreground, 1.5)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
          }

          Text {
            anchors.right: parent.right
            text: root.formatTime(root.trackLength)
            color: Qt.darker(root.bar.foreground, 1.5)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
          }
        }
      }

      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.space(6)

        Button {
          iconText: "󰒮"
          foreground: root.bar.foreground
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.spacing.controlPaddingY
          enabled: root.running && root.player.canGoPrevious
          opacity: enabled ? 1.0 : 0.4
          onClicked: root.previousTrack()
        }

        Button {
          iconText: root.playing ? "󰏤" : "󰐊"
          foreground: root.playing ? root.accentColor : root.bar.foreground
          horizontalPadding: Style.spacing.panelGap
          verticalPadding: Style.spacing.controlPaddingY
          iconSize: Style.font.iconLarge
          enabled: root.running && (root.player.canTogglePlaying || root.player.canPlay || root.player.canPause)
          opacity: enabled ? 1.0 : 0.4
          onClicked: root.playPause()
        }

        Button {
          iconText: "󰒭"
          foreground: root.bar.foreground
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.spacing.controlPaddingY
          enabled: root.running && root.player.canGoNext
          opacity: enabled ? 1.0 : 0.4
          onClicked: root.nextTrack()
        }
      }
    }
  }
}
