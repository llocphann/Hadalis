.pragma library

// Cartesian body coordinates, shared with the editable Blender tentacles.
// Chibi proportions are shared with Blender's editable four-tentacle model.
// Short plump arms end in round tips; two extend and wrap during the pull.
var geometry={"tentacles":4,"headSize":66,"headOffset":10,"rootRadius":8.8,"tipRadius":3.4}
// Two coils cross in front of the victim; two embrace it from behind.
// Blender reads these exact cubic control points for its editable shape keys.
var gripWrapPoints=[[[-16,-42,-10],[-48,-12,10],[-15,-12,38],[28,0,22]],[[-16,-42,-10],[-36,-6,-22],[-14,21,-16],[21,21,-4]],[[16,-42,-10],[36,4,-22],[14,30,-16],[-16,28,-6]],[[16,-42,-10],[48,-6,10],[10,3,38],[-27,11,14]]]
function gripControls(index,rise,wrap) {
    const sign=index<2 ? -1 : 1
    const base=[[sign*16,-42,-10],[sign*25,-42,-14],[sign*26,-40,-14],[sign*23,-38,-14]]
    const raised=[[sign*16,-42,-10],[sign*44,-17,-8],[sign*42,18,-8],[sign*34,28,-2]]
    return base.map((p,i)=>({
        x:p[0]+(raised[i][0]-p[0])*rise+(gripWrapPoints[index][i][0]-raised[i][0])*wrap,
        y:p[1]+(raised[i][1]-p[1])*rise+(gripWrapPoints[index][i][1]-raised[i][1])*wrap,
        z:p[2]+(raised[i][2]-p[2])*rise+(gripWrapPoints[index][i][2]-raised[i][2])*wrap,
        r:geometry.rootRadius+(geometry.tipRadius-geometry.rootRadius)*i/3
    }))
}
function controls(index, curl=1, lift=0, reach=0) {
    const a=(index+.5)*Math.PI*2/geometry.tentacles, x=Math.cos(a), z=Math.sin(a)
    return [
        {x:10*x,y:-10,z:10*z,r:geometry.rootRadius},
        {x:21*x+reach*.25,y:-23+lift,z:21*z,r:8.6},
        {x:34*x+reach*.8,y:-26+curl*6+lift,z:26*z,r:6.2},
        {x:31*x+reach,y:-22+curl*9+lift+reach*.12,z:27*z,r:geometry.tipRadius}
    ]
}
function point(points,t) {
    const u=1-t, a=u*u*u,b=3*u*u*t,c=3*u*t*t,d=t*t*t
    return {x:points[0].x*a+points[1].x*b+points[2].x*c+points[3].x*d,
        y:points[0].y*a+points[1].y*b+points[2].y*c+points[3].y*d,
        z:points[0].z*a+points[1].z*b+points[2].z*c+points[3].z*d,
        r:points[0].r*(1-t)+points[3].r*t}
}
