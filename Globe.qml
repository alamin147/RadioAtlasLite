import QtQuick
import "RadioModel.js" as RadioModel

Item {
    id: root

    property var countries: []
    property var stations: []
    property var selectedStation: null
    property string activeCountryCode: ""
    property real centreLatitude: 18
    property real centreLongitude: -20
    property real globeScale: 1
    property real minimumScale: 0.72
    property real maximumScale: 12
    property color backgroundColor: "#101114"
    property color sphereColor: "#191c20"
    property color landColor: "#787b80"
    property color gridColor: "#8b929a"
    property color outlineColor: "#a7adb4"
    property color signalColor: "#eef0f3"
    property color accentColor: "#8ab4f8"
    property color textColor: "#ffffff"
    property string fontFamily: "sans-serif"
    property var hoveredStation: null
    property real hoverX: 0
    property real hoverY: 0
    property var projectedStations: []

    signal stationActivated(var station)
    signal countryActivated(string code, string name)
    signal interactionStarted()

    function radius() { return Math.min(width, height) * 0.43 * globeScale }
    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
    function focusCoordinate(lat, lon) {
        if (!isFinite(Number(lat)) || !isFinite(Number(lon))) return
        centreLatitude = RadioModel.clamp(Number(lat), -78, 78)
        centreLongitude = RadioModel.wrapLongitude(Number(lon))
    }
    function focusCountry(code) {
        var c = RadioModel.countryCentre(countries, code)
        if (c) focusCoordinate(c.latitude, c.longitude)
    }
    function pxy(lat, lon, r) {
        var p = RadioModel.project(lat, lon, centreLatitude, centreLongitude)
        return { x: width/2 + p.x*r, y: height/2 - p.y*r, z:p.z }
    }

    function drawGrid(ctx, r) {
        ctx.strokeStyle = alpha(gridColor, 0.20)
        ctx.lineWidth = 0.8
        function draw(points) {
            ctx.beginPath(); var drawing=false
            for (var i=0;i<points.length;i++) {
                var p=pxy(points[i][0],points[i][1],r)
                if (p.z < 0) { drawing=false; continue }
                if (!drawing) { ctx.moveTo(p.x,p.y); drawing=true } else ctx.lineTo(p.x,p.y)
            }
            ctx.stroke()
        }
        for (var lat=-60;lat<=60;lat+=30) { var a=[]; for (var lon=-180;lon<=180;lon+=4) a.push([lat,lon]); draw(a) }
        for (var lon2=-150;lon2<=180;lon2+=30) { var b=[]; for (var lat2=-88;lat2<=88;lat2+=4) b.push([lat2,lon2]); draw(b) }
    }

    function drawCountries(ctx, r) {
        var active=activeCountryCode.toUpperCase()
        var rows=Array.isArray(countries)?countries:[]
        for (var i=0;i<rows.length;i++) {
            var f=rows[i]; if (!f || !f.geometry) continue
            var code=String(f.properties&&f.properties.code||"").toUpperCase()
            var polygons=f.geometry.type === "Polygon" ? [f.geometry.coordinates] : f.geometry.coordinates
            if (!Array.isArray(polygons)) continue
            ctx.strokeStyle = code===active ? accentColor : alpha(outlineColor,0.62)
            ctx.lineWidth = code===active ? 1.8 : 0.75
            for (var k=0;k<polygons.length;k++) {
                var ring=polygons[k]&&polygons[k][0]; if (!Array.isArray(ring)) continue
                ctx.beginPath(); var drawing=false
                for (var n=0;n<ring.length;n++) {
                    var p=pxy(ring[n][1],ring[n][0],r)
                    if (p.z < 0) { drawing=false; continue }
                    if (!drawing) { ctx.moveTo(p.x,p.y); drawing=true } else ctx.lineTo(p.x,p.y)
                }
                ctx.stroke()
            }
        }
    }

    function drawStations(ctx, r) {
        var cache=[]; var rows=Array.isArray(stations)?stations:[]
        for (var i=0;i<rows.length;i++) {
            var s=rows[i]; if (!s || s.latitude===null || s.longitude===null) continue
            var p=pxy(s.latitude,s.longitude,r); if (p.z<0) continue
            var selected=selectedStation && selectedStation.uuid===s.uuid
            var size=selected?4.2:1.7+p.z*1.2
            ctx.beginPath(); ctx.arc(p.x,p.y,size,0,Math.PI*2)
            ctx.fillStyle=selected?accentColor:alpha(signalColor,0.48+p.z*0.46); ctx.fill()
            if (selected) { ctx.beginPath();ctx.arc(p.x,p.y,8,0,Math.PI*2);ctx.strokeStyle=alpha(accentColor,.75);ctx.lineWidth=1.2;ctx.stroke() }
            cache.push({station:s,x:p.x,y:p.y,z:p.z})
        }
        projectedStations=cache
    }

    function paint() {
        var ctx=canvas.getContext("2d"); if (!ctx) return
        var r=radius(); ctx.reset(); ctx.fillStyle=backgroundColor; ctx.fillRect(0,0,width,height)
        if (!isFinite(r)||r<=0) return
        var grad=ctx.createRadialGradient(width/2-r*.28,height/2-r*.30,r*.05,width/2,height/2,r)
        grad.addColorStop(0,Qt.lighter(sphereColor,1.55)); grad.addColorStop(.7,sphereColor); grad.addColorStop(1,Qt.darker(sphereColor,1.55))
        ctx.beginPath();ctx.arc(width/2,height/2,r,0,Math.PI*2);ctx.fillStyle=grad;ctx.fill()
        ctx.save();ctx.beginPath();ctx.arc(width/2,height/2,r-.5,0,Math.PI*2);ctx.clip()
        drawGrid(ctx,r);drawCountries(ctx,r);drawStations(ctx,r);ctx.restore()
        ctx.beginPath();ctx.arc(width/2,height/2,r,0,Math.PI*2);ctx.strokeStyle=alpha(outlineColor,.5);ctx.lineWidth=1;ctx.stroke()
    }

    function stationAt(x,y) {
        var best=null,bestD=144
        for (var i=0;i<projectedStations.length;i++) {var p=projectedStations[i],dx=p.x-x,dy=p.y-y,d=dx*dx+dy*dy;if(d<=bestD){best=p.station;bestD=d}}
        return best
    }
    function activateAt(x,y) {
        var station=stationAt(x,y); if (station) { stationActivated(station); return }
        var r=radius(), nx=(x-width/2)/r, ny=-(y-height/2)/r
        var coord=RadioModel.unproject(nx,ny,centreLatitude,centreLongitude); if(!coord)return
        var country=RadioModel.countryAt(countries,coord.latitude,coord.longitude)
        if(country&&country.code&&country.code!=="-99") countryActivated(String(country.code).toUpperCase(),String(country.name||country.code))
    }

    onCountriesChanged: canvas.requestPaint()
    onStationsChanged: canvas.requestPaint()
    onSelectedStationChanged: canvas.requestPaint()
    onActiveCountryCodeChanged: canvas.requestPaint()
    onCentreLatitudeChanged: canvas.requestPaint()
    onCentreLongitudeChanged: canvas.requestPaint()
    onGlobeScaleChanged: canvas.requestPaint()
    onWidthChanged: canvas.requestPaint()
    onHeightChanged: canvas.requestPaint()

    Canvas { id: canvas; anchors.fill: parent; renderStrategy: Canvas.Cooperative; onPaint: root.paint() }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: pressed ? Qt.ClosedHandCursor : (root.hoveredStation ? Qt.PointingHandCursor : Qt.OpenHandCursor)
        property real lastX: 0
        property real lastY: 0
        property real movement: 0
        onPressed: function(m) { root.interactionStarted(); lastX=m.x;lastY=m.y;movement=0;root.hoveredStation=null }
        onPositionChanged: function(m) {
            root.hoverX=m.x;root.hoverY=m.y
            if (!(pressedButtons & Qt.LeftButton)) { root.hoveredStation=root.stationAt(m.x,m.y); return }
            var dx=m.x-lastX,dy=m.y-lastY
            root.centreLongitude=RadioModel.wrapLongitude(root.centreLongitude-dx*.22/root.globeScale)
            root.centreLatitude=RadioModel.clamp(root.centreLatitude+dy*.18/root.globeScale,-78,78)
            movement+=Math.abs(dx)+Math.abs(dy);lastX=m.x;lastY=m.y
        }
        onReleased: function(m) { if(movement<7) root.activateAt(m.x,m.y); root.hoveredStation=root.stationAt(m.x,m.y) }
        onExited: if (!(pressedButtons & Qt.LeftButton)) root.hoveredStation=null
        onWheel: function(w) { root.interactionStarted(); root.globeScale=RadioModel.clamp(root.globeScale*Math.exp(w.angleDelta.y/720),root.minimumScale,root.maximumScale);w.accepted=true }
    }

    Rectangle {
        visible: !!root.hoveredStation && !mouse.pressed
        x: Math.min(root.width-width-8,Math.max(8,root.hoverX+14))
        y: Math.min(root.height-height-8,Math.max(8,root.hoverY+14))
        width: Math.min(260,tip.implicitWidth+20); height: tip.implicitHeight+14
        color: Qt.rgba(root.backgroundColor.r,root.backgroundColor.g,root.backgroundColor.b,.94)
        border.color: root.alpha(root.outlineColor,.5);border.width:1;radius:6
        Text { id:tip;anchors.centerIn:parent;width:Math.min(240,implicitWidth);text:root.hoveredStation?root.hoveredStation.name+(root.hoveredStation.estimatedLocation?" · approx.":""):"";color:root.textColor;font.family:root.fontFamily;font.pixelSize:12;elide:Text.ElideRight }
    }
}
