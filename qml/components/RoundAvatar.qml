import QtQuick

// A round picture from the network, fetched fresh each time it is created so a changed
// picture shows up. It retries after a failed fetch and shows a letter until it loads.
Canvas {
    id: avatar
    property string source: ""
    property string fallback: ""
    property var retryDelays: [5000, 30000, 120000]
    property int retries: 0
    property string loadedUrl: ""
    property string requestedUrl: ""
    readonly property bool ready: loadedUrl !== ""
    readonly property color backdrop: Colors.surfaceHi
    readonly property color outline: Colors.accent
    implicitWidth: 64
    implicitHeight: 64
    Accessible.role: Accessible.Graphic
    onBackdropChanged: requestPaint()
    onOutlineChanged: requestPaint()
    property bool created: false
    onSourceChanged: if (created) fetch()
    Component.onCompleted: {
        created = true;
        fetch();
    }
    function fetch() {
        if (!source) return;
        if (requestedUrl) unloadImage(requestedUrl);
        // A unique address skips caches. An image already cached never emits imageLoaded.
        requestedUrl = source + (source.indexOf("?") >= 0 ? "&" : "?") + "t=" + Date.now();
        loadImage(requestedUrl);
        finishFetch();
    }
    function finishFetch() {
        if (isImageLoaded(requestedUrl)) {
            retries = 0;
            loadedUrl = requestedUrl;
            requestPaint();
        } else if (isImageError(requestedUrl) && retries < retryDelays.length) {
            retry.interval = retryDelays[retries];
            retry.restart();
        }
    }
    onImageLoaded: finishFetch()
    Timer {
        id: retry
        onTriggered: {
            ++avatar.retries;
            avatar.fetch();
        }
    }
    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        ctx.beginPath();
        ctx.arc(width / 2, height / 2, width / 2 - 2, 0, Math.PI * 2);
        ctx.closePath();
        ctx.fillStyle = backdrop;
        ctx.fill();
        if (ready) {
            ctx.save();
            ctx.clip();
            ctx.drawImage(loadedUrl, 2, 2, width - 4, height - 4);
            ctx.restore();
        }
        ctx.lineWidth = 2;
        ctx.strokeStyle = outline;
        ctx.stroke();
    }
    Text {
        anchors.centerIn: parent
        visible: !avatar.ready
        text: avatar.fallback
        color: Colors.accent
        font.family: Colors.displayFont
        font.pixelSize: Typography.contentTitle
    }
}
