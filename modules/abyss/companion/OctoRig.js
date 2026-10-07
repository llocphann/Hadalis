.pragma library

// Cartesian body coordinates, shared with the editable Blender tentacles.
// Chibi proportions are shared with Blender's editable four-tentacle model.
// Short plump arms end in round tips; two extend and wrap during the pull.
var geometry={"tentacles":4,"headSize":66,"headOffset":10,"rootRadius":8.8,"tipRadius":3.4}
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
