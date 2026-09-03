var radians = Math.PI / 180
var degrees = 180 / Math.PI
var estimatedLocationCache = ({})

function clamp(value, minimum, maximum) {
  return Math.max(minimum, Math.min(maximum, value))
}

function wrapLongitude(value) {
  var wrapped = (Number(value) + 180) % 360
  if (wrapped < 0) wrapped += 360
  return wrapped - 180
}

function project(latitude, longitude, centreLatitude, centreLongitude) {
  var phi = Number(latitude) * radians
  var lambda = wrapLongitude(Number(longitude) - Number(centreLongitude)) * radians
  var phi0 = Number(centreLatitude) * radians
  var cosPhi = Math.cos(phi)
  var sinPhi = Math.sin(phi)
  var cosPhi0 = Math.cos(phi0)
  var sinPhi0 = Math.sin(phi0)
  return {
    x: cosPhi * Math.sin(lambda),
    y: cosPhi0 * sinPhi - sinPhi0 * cosPhi * Math.cos(lambda),
    z: sinPhi0 * sinPhi + cosPhi0 * cosPhi * Math.cos(lambda)
  }
}

function unproject(x, y, centreLatitude, centreLongitude) {
  var rho2 = x * x + y * y
  if (rho2 > 1) return null
  var z = Math.sqrt(Math.max(0, 1 - rho2))
  var phi0 = Number(centreLatitude) * radians
  var cosPhi0 = Math.cos(phi0)
  var sinPhi0 = Math.sin(phi0)
  var latitude = Math.asin(y * cosPhi0 + z * sinPhi0)
  var longitude = Number(centreLongitude) * radians + Math.atan2(x, z * cosPhi0 - y * sinPhi0)
  return { latitude: latitude * degrees, longitude: wrapLongitude(longitude * degrees) }
}

function pointInRing(longitude, latitude, ring) {
  var inside = false
  if (!Array.isArray(ring) || ring.length < 3) return false
  for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    var xi = Number(ring[i][0]); var yi = Number(ring[i][1])
    var xj = Number(ring[j][0]); var yj = Number(ring[j][1])
    var crosses = (yi > latitude) !== (yj > latitude) &&
      longitude < (xj - xi) * (latitude - yi) / ((yj - yi) || 1e-12) + xi
    if (crosses) inside = !inside
  }
  return inside
}

function pointInPolygon(longitude, latitude, polygon) {
  if (!Array.isArray(polygon) || polygon.length === 0) return false
  if (!pointInRing(longitude, latitude, polygon[0])) return false
  for (var i = 1; i < polygon.length; i++) if (pointInRing(longitude, latitude, polygon[i])) return false
  return true
}

function countryAt(features, latitude, longitude) {
  var rows = Array.isArray(features) ? features : []
  for (var i = 0; i < rows.length; i++) {
    var feature = rows[i]
    if (!feature || !feature.geometry) continue
    var geometry = feature.geometry
    var polygons = geometry.type === "Polygon" ? [geometry.coordinates] : geometry.coordinates
    if (!Array.isArray(polygons)) continue
    for (var p = 0; p < polygons.length; p++) {
      if (pointInPolygon(longitude, latitude, polygons[p])) return feature.properties || null
    }
  }
  return null
}

function countryCentre(features, code) {
  var rows = Array.isArray(features) ? features : []
  var wanted = String(code || "").toUpperCase()
  for (var i = 0; i < rows.length; i++) {
    var feature = rows[i]
    if (!feature || !feature.geometry || !feature.properties) continue
    if (String(feature.properties.code || "").toUpperCase() !== wanted) continue
    var geometry = feature.geometry
    var polygons = geometry.type === "Polygon" ? [geometry.coordinates] : geometry.coordinates
    if (!Array.isArray(polygons)) return null
    var best = null
    for (var p = 0; p < polygons.length; p++) {
      var ring = polygons[p] && polygons[p][0]
      if (!Array.isArray(ring) || ring.length < 3) continue
      var minX=Infinity,maxX=-Infinity,minY=Infinity,maxY=-Infinity
      for (var n=0;n<ring.length;n++) {
        var x=Number(ring[n][0]), y=Number(ring[n][1])
        if (!isFinite(x)||!isFinite(y)) continue
        minX=Math.min(minX,x); maxX=Math.max(maxX,x); minY=Math.min(minY,y); maxY=Math.max(maxY,y)
      }
      var area=(maxX-minX)*(maxY-minY)
      if (!best || area>best.area) best={area:area, latitude:(minY+maxY)/2, longitude:wrapLongitude((minX+maxX)/2)}
    }
    return best ? { latitude:best.latitude, longitude:best.longitude } : null
  }
  return null
}

function estimatedCountryLocation(features, code, key) {
  var wanted = String(code || "").toUpperCase()
  var cacheKey = "$" + wanted + ":" + String(key || wanted)
  if (estimatedLocationCache[cacheKey] !== undefined) return estimatedLocationCache[cacheKey]
  var centre = countryCentre(features, wanted)
  estimatedLocationCache[cacheKey] = centre
  return centre
}

function mergeStations(primary, secondary, maximum) {
  var groups=[primary,secondary], output=[], seen=({}), limit=Math.max(1,Number(maximum||500))
  for (var g=0;g<groups.length;g++) {
    var rows=Array.isArray(groups[g])?groups[g]:[]
    for (var i=0;i<rows.length && output.length<limit;i++) {
      var row=rows[i]
      if (!row || !row.uuid) continue
      var key="$"+row.uuid
      if (seen[key] !== undefined) {
        if (g>0) output[seen[key]]=row
        continue
      }
      seen[key]=output.length
      output.push(row)
    }
  }
  return output
}

function prioritizeStations(priority, fallback, maximum) {
  var rows=[priority,fallback], output=[], seen=({}), limit=Math.max(1,Number(maximum||500))
  for (var g=0;g<rows.length;g++) {
    var group=Array.isArray(rows[g])?rows[g]:[]
    for (var i=0;i<group.length && output.length<limit;i++) {
      var row=group[i]
      if (!row || !row.uuid || seen["$"+row.uuid]) continue
      seen["$"+row.uuid]=true; output.push(row)
    }
  }
  return output
}

function mergeGeoStations(primary, secondary, countries) {
  var rows=mergeStations(primary, secondary, 3000), output=[]
  for (var i=0;i<rows.length;i++) {
    var row=rows[i]
    if (row.latitude === null || row.longitude === null || row.latitude === undefined || row.longitude === undefined) {
      var estimate=estimatedCountryLocation(countries,row.countryCode,row.uuid)
      if (!estimate) continue
      var copy=({}); for (var k in row) copy[k]=row[k]
      copy.latitude=estimate.latitude; copy.longitude=estimate.longitude; copy.estimatedLocation=true
      output.push(copy)
    } else output.push(row)
  }
  return output
}

function searchStations(stations, query, maximum) {
  var rows=Array.isArray(stations)?stations:[], wanted=String(query||"").trim().toLowerCase(), output=[]
  var limit=Math.max(1,Number(maximum||150)); if (!wanted) return []
  for (var i=0;i<rows.length && output.length<limit;i++) {
    var station=rows[i]; if (!station) continue
    var fields=[station.name,station.country,station.countryCode,station.state,station.language,station.tags,station.codec]
    for (var j=0;j<fields.length;j++) if (String(fields[j]||"").toLowerCase().indexOf(wanted)>=0) {output.push(station);break}
  }
  return output
}

function stationsForCountry(stations, code, maximum) {
  var rows=Array.isArray(stations)?stations:[], wanted=String(code||"").toUpperCase(), output=[]
  var limit=Math.max(1,Number(maximum||150))
  for (var i=0;i<rows.length && output.length<limit;i++) if (String(rows[i]&&rows[i].countryCode||"").toUpperCase()===wanted) output.push(rows[i])
  return output
}

function stationWindow(stations, uuid, maximum) {
  var rows=Array.isArray(stations)?stations:[], index=indexByUuid(rows,uuid)
  if (index<0) return []
  var limit=Math.min(rows.length,Math.max(1,Number(maximum||500))), before=Math.floor((limit-1)/2)
  var start=(index-before+rows.length)%rows.length, output=[]
  for (var i=0;i<limit;i++) output.push(rows[(start+i)%rows.length])
  return output
}

function compactTags(tags, maximum) {
  var parts=String(tags||"").split(","), output=[], limit=Math.max(1,Number(maximum||2))
  for (var i=0;i<parts.length && output.length<limit;i++) {var part=parts[i].trim(); if (part && output.indexOf(part)<0) output.push(part)}
  return output.join(" · ")
}

function stationMeta(station) {
  if (!station) return ""
  var parts=[]; if (station.countryCode) parts.push(station.countryCode); if (station.codec) parts.push(station.codec)
  if (Number(station.bitrate)>0) parts.push(Number(station.bitrate)+" kbps")
  return parts.join(" · ")
}

function indexByUuid(stations, uuid) {
  var rows=Array.isArray(stations)?stations:[]
  for (var i=0;i<rows.length;i++) if (rows[i] && rows[i].uuid===uuid) return i
  return -1
}
